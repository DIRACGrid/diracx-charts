#!/usr/bin/env bash
# Publish a chart to an OCI registry, once per chart version.
#
# usage: publish_chart_oci.sh CHART_DIR
#
# Environment:
#   REGISTRY           where to push, e.g. ghcr.io/diracgrid/diracx-charts
#   REGISTRY_USER      account for the registry (optional for a registry without login)
#   REGISTRY_PASSWORD  its password or token
#   REGISTRY_SCHEME    https (default); http is only for tests with a local registry
#
# A registry lets a tag be overwritten, so the script first asks whether the
# version exists and stops if it does. Only a clear "not found" allows a push.
set -euo pipefail

chart_dir=$1
registry=${REGISTRY:?}
scheme=${REGISTRY_SCHEME:-https}
host=${registry%%/*}
path=${registry#*/}

name=$(helm show chart "${chart_dir}" | sed -n 's/^name: *//p')
version=$(helm show chart "${chart_dir}" | sed -n 's/^version: *//p' | tr -d '"')
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
  200)
    echo "${name} ${version} is already published: nothing to do"
    echo "published=false" >> "${GITHUB_OUTPUT:-/dev/null}"
    exit 0
    ;;
  404) ;;
  *)
    echo "::error::Cannot tell whether ${name} ${version} exists (HTTP ${status}): not publishing"
    exit 1
    ;;
esac

work=$(mktemp -d)
helm package "${chart_dir}" --destination "${work}"

push_flags=()
if [[ "${scheme}" == "http" ]]; then
  push_flags=(--plain-http)
fi
if [[ -n "${REGISTRY_USER:-}" ]]; then
  helm registry login "${host}" --username "${REGISTRY_USER}" --password-stdin <<< "${REGISTRY_PASSWORD}"
fi
helm push "${work}/${name}-${version}.tgz" "oci://${registry}" "${push_flags[@]}" 2>&1 | tee "${work}/push.log"
digest=$(sed -n 's/^Digest: *//p' "${work}/push.log")
if [[ ! "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "::error::No digest in the output of helm push"
  exit 1
fi

echo "Published ${name} ${version} to oci://${registry}/${name} (${digest})"
{
  echo "published=true"
  echo "name=${registry}/${name}"
  echo "version=${version}"
  echo "digest=${digest}"
} >> "${GITHUB_OUTPUT:-/dev/null}"
