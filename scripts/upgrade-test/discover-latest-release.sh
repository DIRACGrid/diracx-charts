#!/usr/bin/env bash
# Discover the latest published chart release to upgrade from.
#
# Sets $GITHUB_OUTPUT entries:
#   tag           - the released git tag (e.g. "diracx-1.1.0-beta.1")
#   version       - just the version part (e.g. "1.1.0-beta.1")
#   skip          - "true" if the upgrade test should be skipped
#   skip_reason   - human-readable reason when skip=true
#
# Skip conditions:
#   - no prior diracx-* release exists
#   - PR's diracx/Chart.yaml version equals the latest released version
#     (chart-ci.yml's check-version-bump is the right place to enforce that
#     templates+version-bump come together; we just avoid a redundant failure)

set -euo pipefail

if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
  echo "GITHUB_OUTPUT is not set; this script is intended to run in GitHub Actions" >&2
  exit 1
fi

# chart-releaser-action publishes drafts as a workaround for immutable releases
# (see chart-ci.yml). Excluding drafts gets us the actual published versions.
# Prereleases are included on purpose — the project ships betas as the public
# version and we want each beta to upgrade cleanly from its predecessor.
candidates=$(gh release list --limit 50 \
  --json tagName,isDraft,isPrerelease,publishedAt \
  | jq -r '.[]
           | select(.isDraft | not)
           | select(.tagName | startswith("diracx-"))
           | "\(.publishedAt) \(.tagName)"' \
  | sort)

latest_tag=$(echo "$candidates" | awk 'NF{print $2}' | tail -n1)

if [[ -z "$latest_tag" ]]; then
  {
    echo "skip=true"
    echo "skip_reason=no prior diracx-* release found"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

released_version="${latest_tag#diracx-}"
pr_version=$(grep -E '^version:' diracx/Chart.yaml | head -n1 \
  | sed -E 's/^version:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/')

if [[ "$pr_version" == "$released_version" ]]; then
  {
    echo "skip=true"
    echo "skip_reason=PR Chart.yaml version equals released version ($pr_version)"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

{
  echo "tag=$latest_tag"
  echo "version=$released_version"
  echo "skip=false"
} >> "$GITHUB_OUTPUT"

echo "Will test upgrade $released_version -> $pr_version"
