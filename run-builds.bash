#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDON_REPO="${HOME}/projects/kaptain/buildon/buildon-github-actions"
RESULTS_DIR="${BUILDON_REPO}/kaptain-test-results"
STATUS_DIR="${RESULTS_DIR}/.status"

# shellcheck source=Branchoutfile
source "${SCRIPT_DIR}/Branchoutfile"

rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR" "$STATUS_DIR"

run_one() {
  local repo_name="$1"
  local group="${repo_name#"${BRANCHOUT_PREFIX}-"}"
  group="${group%%-*}"
  local repo_dir="${SCRIPT_DIR}/${group}/${repo_name}"
  local output_file="${RESULTS_DIR}/${repo_name}.log"
  local status_file="${STATUS_DIR}/${repo_name}"
  if (cd "$repo_dir" && kaptain build) >"$output_file" 2>&1; then
    rm -f "$output_file"
    echo "pass" > "$status_file"
  else
    echo "fail" > "$status_file"
  fi
}

declare -a repos=()
while IFS= read -r repo_name; do
  [[ -z "$repo_name" ]] && continue
  repos+=("$repo_name")
done < "${SCRIPT_DIR}/Branchoutprojects"

start_time=$(date +%s)
started=0
for repo_name in "${repos[@]}"; do
  run_one "$repo_name" &
  started=$((started + 1))
done
echo "Started ${started} builds in parallel, waiting..."
wait
end_time=$(date +%s)
elapsed=$((end_time - start_time))

passed=0
failed=0
declare -a results=()
for repo_name in "${repos[@]}"; do
  group="${repo_name#"${BRANCHOUT_PREFIX}-"}"
  group="${group%%-*}"
  label="${group}/${repo_name}"
  status="$(cat "${STATUS_DIR}/${repo_name}" 2>/dev/null || echo "fail")"
  if [[ "$status" == "pass" ]]; then
    results+=("✔ ${label}")
    passed=$((passed + 1))
  else
    results+=("✘ ${label}")
    failed=$((failed + 1))
  fi
done

rm -rf "$STATUS_DIR"

total=$((passed + failed))
echo ""
echo "Results: ${passed}/${total} passed, ${failed}/${total} failed in ${elapsed}s"
echo ""
for line in "${results[@]}"; do
  echo "  $line"
done

if [[ "$failed" -gt 0 ]]; then
  echo ""
  echo "Failure logs: ${RESULTS_DIR}/"
  exit 1
fi
