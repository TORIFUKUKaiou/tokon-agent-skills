#!/usr/bin/env bash
# レビューの対象になった PR が出るまで待ち、出たら1行1件の JSON で出して終わる。
#
# 対象: open で、Draft でなく、タイトルが WIP でなく、作者が自分でない PR。
# まだ出していない番号だけを出す（出した番号は状態ファイルに記録する）。
# Draft が外れた PR や、タイトルから WIP が消えた PR も、その時点で出る。
#
# 使い方:
#   wait-reviewable-pr.sh OWNER/REPO [--interval 秒] [--timeout 秒] [--state ファイル]
#   wait-reviewable-pr.sh OWNER/REPO --init   # 今の対象を記録だけして終わる（既存の PR を出さない）
#   wait-reviewable-pr.sh OWNER/REPO --list   # 今の対象を出すだけ（記録しない・待たない）
#
# 終了コード: 0 = 出した、8 = 時間切れ（gh event listen に合わせた）、2 = 使い方の誤り、1 = その他
# gh は、対象のリポジトリのアカウントになるディレクトリで実行すること。

set -euo pipefail

repo=""
interval=180
timeout=0
state=""
mode="wait"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval) interval="$2"; shift 2 ;;
    --timeout) timeout="$2"; shift 2 ;;
    --state) state="$2"; shift 2 ;;
    --init) mode="init"; shift ;;
    --list) mode="list"; shift ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) repo="$1"; shift ;;
  esac
done

if [[ ! "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "usage: $0 OWNER/REPO [--interval SEC] [--timeout SEC] [--state FILE] [--init|--list]" >&2
  exit 2
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/pr-watch"
state="${state:-$state_dir/${repo/\//__}.seen}"
mkdir -p "$(dirname "$state")"
touch "$state"

me="$(gh api user --jq .login)"
if [[ ! "$me" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "unexpected login: $me" >&2
  exit 1
fi

# 対象の PR を「番号<TAB>JSON」で出す。gh の --jq は --arg を受け付けないので、ログイン名は式に埋め込む
# （上で文字の種類を確かめている）
filter='.[]
  | select(.isDraft | not)
  | select(.title | test("^\\s*[\\[(]?\\s*wip\\b"; "i") | not)
  | select(.author.login != "ME")
  | "\(.number)\t\({number, title, author: .author.login, url, headRefOid, baseRefName, createdAt} | tojson)"'
filter="${filter/ME/$me}"

reviewable() {
  gh pr list --repo "$repo" --state open --limit 100 \
    --json number,title,author,isDraft,url,headRefOid,baseRefName,createdAt \
    --jq "$filter"
}

case "$mode" in
  list)
    reviewable | cut -f2
    exit 0
    ;;
  init)
    reviewable | cut -f1 >> "$state"
    sort -u -o "$state" "$state"
    echo "recorded $(wc -l < "$state" | tr -d ' ') PR(s) in $state" >&2
    exit 0
    ;;
esac

start=$(date +%s)
echo "watching $repo every ${interval}s (state: $state)" >&2
while :; do
  if lines="$(reviewable)"; then
    found=0
    while IFS=$'\t' read -r number json; do
      [[ -z "$number" ]] && continue
      if ! grep -qx "$number" "$state"; then
        echo "$json"
        echo "$number" >> "$state"
        found=1
      fi
    done <<< "$lines"
    if [[ $found -eq 1 ]]; then
      exit 0
    fi
  else
    echo "gh pr list failed; retrying" >&2
  fi
  if [[ $timeout -gt 0 && $(( $(date +%s) - start )) -ge $timeout ]]; then
    echo "timeout" >&2
    exit 8
  fi
  sleep "$interval"
done
