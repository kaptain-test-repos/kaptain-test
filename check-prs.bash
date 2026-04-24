#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_ORG="kaptain-test-repos"

# shellcheck source=Branchoutfile
source "${SCRIPT_DIR}/Branchoutfile"

branch="${1:-$(git -C "${SCRIPT_DIR}" rev-parse --abbrev-ref HEAD)}"

echo "Checking PR status on branch: ${branch}"
echo ""

declare -a results=()
passing=0
failing=0
pending=0
missing=0

while IFS= read -r repo_name; do
  [[ -z "$repo_name" ]] && continue
  group="${repo_name#"${BRANCHOUT_PREFIX}-"}"
  group="${group%%-*}"
  label="${group}/${repo_name}"
  remote_repo="${REMOTE_ORG}/${repo_name}"

  pr_number=$(gh pr list --repo "$remote_repo" --state open --head "$branch" --json number --jq '.[0].number // empty' 2>/dev/null || echo "")

  if [[ -z "$pr_number" ]]; then
    results+=("? ${label} (no open PR on ${branch})")
    missing=$((missing + 1))
    continue
  fi

  buckets=$(gh pr checks "$pr_number" --repo "$remote_repo" --json bucket --jq '[.[].bucket] | group_by(.) | map({key: .[0], value: length}) | from_entries' 2>/dev/null || echo "{}")

  pass_count=$(echo "$buckets" | jq -r '.pass // 0')
  fail_count=$(echo "$buckets" | jq -r '.fail // 0')
  pending_count=$(echo "$buckets" | jq -r '.pending // 0')
  skipping_count=$(echo "$buckets" | jq -r '.skipping // 0')
  cancel_count=$(echo "$buckets" | jq -r '.cancel // 0')

  summary="pass:${pass_count} fail:${fail_count} pending:${pending_count} skip:${skipping_count} cancel:${cancel_count}"

  if [[ "$fail_count" -gt 0 || "$cancel_count" -gt 0 ]]; then
    results+=("✘ ${label} PR#${pr_number} (${summary})")
    failing=$((failing + 1))
  elif [[ "$pending_count" -gt 0 ]]; then
    results+=("⋯ ${label} PR#${pr_number} (${summary})")
    pending=$((pending + 1))
  else
    results+=("✔ ${label} PR#${pr_number} (${summary})")
    passing=$((passing + 1))
  fi
done < "${SCRIPT_DIR}/Branchoutprojects"

total=$((passing + failing + pending + missing))
echo "Results: ${passing}/${total} passing, ${failing}/${total} failing, ${pending}/${total} pending, ${missing}/${total} missing on branch ${branch}"
echo ""
for line in "${results[@]}"; do
  echo "  $line"
done

[[ "$failing" -eq 0 && "$pending" -eq 0 && "$missing" -eq 0 ]]
