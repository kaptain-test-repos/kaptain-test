#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDON_REPO="kube-kaptain/buildon-github-actions"

# shellcheck source=Branchoutfile
source "${SCRIPT_DIR}/Branchoutfile"

pr_count=$(gh pr list --repo "$BUILDON_REPO" --state open --json number --jq 'length')

if [[ "$pr_count" -eq 0 ]]; then
  echo "ERROR: No open PRs on $BUILDON_REPO" >&2
  exit 1
fi

if [[ "$pr_count" -gt 1 ]]; then
  echo "ERROR: $pr_count open PRs on $BUILDON_REPO — expected exactly 1:" >&2
  gh pr list --repo "$BUILDON_REPO" --state open --json number,title,headRefName --jq '.[] | "  #\(.number) [\(.headRefName)] \(.title)"' >&2
  exit 1
fi

branch=$(gh pr list --repo "$BUILDON_REPO" --state open --json headRefName --jq '.[0].headRefName')
echo "Found 1 open PR on $BUILDON_REPO, branch: $branch"

while IFS= read -r repo_name; do
  [[ -z "$repo_name" ]] && continue
  group="${repo_name#"${BRANCHOUT_PREFIX}-"}"
  group="${group%%-*}"
  build_yaml="${SCRIPT_DIR}/${group}/${repo_name}/.github/workflows/build.yaml"
  if [[ -f "$build_yaml" ]]; then
    sed -i '' "s|${BUILDON_REPO}\(/.github/workflows/[^@]*\)@.*|${BUILDON_REPO}\1@${branch}|g" "$build_yaml"
    echo "  Updated: ${group}/${repo_name}"
  fi
done < "${SCRIPT_DIR}/Branchoutprojects"

echo "Done. All build.yaml files now reference @${branch}"
