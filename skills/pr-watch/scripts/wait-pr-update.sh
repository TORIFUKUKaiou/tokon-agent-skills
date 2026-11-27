#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 [HOST/]OWNER/REPO PR --snapshot | --since SHA256 [--interval SEC]"
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi

repository=${1:-}
number=${2:-}
mode=${3:-}
if [[ ! $repository =~ ^([A-Za-z0-9.-]+/)?[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ || ! $number =~ ^[1-9][0-9]*$ ]]; then
  usage >&2
  exit 2
fi

hostname=github.com
repo=$repository
if [[ $repository == */*/* ]]; then
  hostname=${repository%%/*}
  repo=${repository#*/}
fi

baseline=${4:-}
interval=900
case "$mode" in
  --snapshot) [[ $# == 3 ]] || { usage >&2; exit 2; } ;;
  --since)
    [[ $# == 4 || ( $# == 6 && $5 == --interval ) ]] || { usage >&2; exit 2; }
    interval=${6:-900}
    if [[ ! $baseline =~ ^[a-f0-9]{64}$ || ! $interval =~ ^[1-9][0-9]*$ ]]; then
      usage >&2
      exit 2
    fi
    ;;
  *) usage >&2; exit 2 ;;
esac

endpoint="repos/$repo"
comment_fields='map({id, updated_at}) | sort_by(.id)'
# イベントで起きたあと、API に反映されるのを待って比べ直す間隔（秒）
settle_delays=(10 30)

read_pages() {
  gh api --hostname "$hostname" --paginate --slurp "$1?per_page=100" |
    jq -ceS "add // [] | $2"
}

read_pr() {
  # statusCheckRollup は CheckRun（name・workflowName・status・conclusion）と StatusContext
  # （context・state）が混ざるので、ワークフロー名・名前・結果の組にそろえる。ワークフロー名で、
  # 別のワークフローにある同じ名前のチェックを区別する。実行の URL や時刻は入れない（同じ結果の
  # 再実行では起きない）。
  # reviewRequests は、依頼中のレビュアー（User は login、Team は slug）の一覧にそろえる。
  # レビューの依頼・再依頼・取り消しを拾う。gh event listen にはこのイベントがないので、定期確認で拾う
  gh pr view "$number" --repo "$repository" --json \
    baseRefName,baseRefOid,body,headRefOid,isDraft,reviewDecision,reviewRequests,state,title,statusCheckRollup |
    jq -ceS 'select(type == "object" and (.headRefOid | type == "string"))
      | .statusCheckRollup |= ((. // [])
          | map({workflow: (.workflowName // ""), name: (.name // .context),
                 result: (.conclusion // .state // .status)})
          | sort_by(.workflow, .name, .result))
      | .reviewRequests |= ((. // []) | map({type: .__typename, name: (.login // .slug // .name)})
          | sort_by(.type, .name))' || return
  read_pages "$endpoint/pulls/$number/reviews" \
    'map({id, body, state, commit_id, submitted_at}) | sort_by(.id)' || return
  read_pages "$endpoint/pulls/$number/comments" "$comment_fields" || return
  read_pages "$endpoint/issues/$number/comments" "$comment_fields"
}

snapshot() {
  read_pr | shasum -a 256 | cut -d ' ' -f 1
}

if [[ $mode == --snapshot ]]; then
  current=$(snapshot)
  printf '%s\n' "$current"
  exit 0
fi

# 待つ。イベントで起きたら 0、時間切れか定期確認なら 1 を返す。
# gh event listen が失敗したら、その回は定期確認で待ち、次の回にまたイベントを試す
# （一時的なエラーで、ずっと定期確認に切り替わったままにしない）。
event_failures=0
wait_for_update() {
  if [[ $hostname == github.com ]]; then
    local status=0
    gh event listen --resource "https://github.com/$repo/pull/$number" \
      --event com.github.pull_request.review.submitted.v1,com.github.pull_request.head.changed.v1,com.github.pull_request.state.changed.v1,com.github.pull_request.check_suite.status.changed.v1 \
      --timeout "${interval}s" >/dev/null 2>&1 || status=$?
    if [[ $status == 0 ]]; then
      event_failures=0
      return 0
    fi
    if [[ $status == 8 ]]; then
      event_failures=0
      return 1
    fi
    event_failures=$((event_failures + 1))
    if [[ $event_failures == 1 ]]; then
      echo 'gh event listen failed; using a periodic check this time' >&2
    fi
  fi
  sleep "$interval"
  return 1
}

failures=0
check() {
  if current=$(snapshot); then
    failures=0
    if [[ $current != "$baseline" ]]; then
      printf '%s\n' "$current"
      exit 0
    fi
    return 0
  fi
  failures=$((failures + 1))
  if [[ $failures == 3 ]]; then
    echo 'failed to read PR state three times' >&2
    exit 1
  fi
  return 1
}

while :; do
  if ! check; then
    sleep "$interval"
    continue
  fi
  if wait_for_update; then
    # イベントが来たのに API にまだ反映されていなければ、少し待って比べ直す
    for delay in "${settle_delays[@]}"; do
      check || true
      sleep "$delay"
    done
  fi
done
