#!/usr/bin/env bash
# One-off: copy the chart versions already published on the old Helm repository
# to the OCI registry, so that every version is available from one place.
#
# usage: backfill_charts_oci.sh
#
# Environment: REGISTRY, REGISTRY_USER, REGISTRY_PASSWORD, REGISTRY_SCHEME as in
# publish_chart_oci.sh; INDEX_URL (default: the old repository's index.yaml).
#
# Each package is downloaded from the URL in the index, checked against the
# digest in the index, and pushed unchanged. A version already in the registry
# is left alone.
set -euo pipefail

registry=${REGISTRY:?}
scheme=${REGISTRY_SCHEME:-https}
index_url=${INDEX_URL:-https://charts.diracgrid.org/index.yaml}
host=${registry%%/*}
path=${registry#*/}
work=$(mktemp -d)

curl -fsSL "${index_url}" -o "${work}/index.yaml"

push_flags=()
if [[ "${scheme}" == "http" ]]; then
  push_flags=(--plain-http)
fi
if [[ -n "${REGISTRY_USER:-}" ]]; then
  helm registry login "${host}" --username "${REGISTRY_USER}" --password-stdin <<< "${REGISTRY_PASSWORD}"
fi

pushed=0
skipped=0
while IFS=$'\t' read -r name version url digest; do
  [[ -n "${name}" ]] || continue
  repository="${path}/${name}"
  auth=()
  if [[ -n "${REGISTRY_USER:-}" ]]; then
    token=$(curl -fsS -u "${REGISTRY_USER}:${REGISTRY_PASSWORD}" \
      "${scheme}://${host}/token?service=${host}&scope=repository:${repository}:pull" | jq -er .token)
    auth=(-H "Authorization: Bearer ${token}")
  fi
  status=$(curl -sS -o /dev/null -w '%{http_code}' -I "${auth[@]}" \
    -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
    "${scheme}://${host}/v2/${repository}/manifests/${version}")
  case "${status}" in
    200) skipped=$((skipped + 1)); continue ;;
    404) ;;
    *) echo "::error::Cannot tell whether ${name} ${version} exists (HTTP ${status})"; exit 1 ;;
  esac
  file="${work}/${name}-${version}.tgz"
  curl -fsSL "${url}" -o "${file}"
  echo "${digest}  ${file}" | sha256sum --check --quiet -
  helm push "${file}" "oci://${registry}" "${push_flags[@]}"
  pushed=$((pushed + 1))
done < <(yq '.entries[][] | [.name, .version, .urls[0], .digest] | @tsv' "${work}/index.yaml")

echo "Pushed ${pushed} versions, ${skipped} were already there"
