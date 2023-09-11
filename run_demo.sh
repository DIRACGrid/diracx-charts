#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

UNICORN_EMOJI="\U1F984"
SKULL_EMOJI="\U1F480"

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

tmp_dir=$(mktemp -d)
demo_dir="${script_dir}/.demo"
mkdir -p "${demo_dir}"
export KUBECONFIG="${demo_dir}/kube.conf"
export HELM_DATA_HOME="${demo_dir}/helm_data"

function cleanup(){
  trap - SIGTERM;
  echo "Cleaning up";
  if [[ -f "${demo_dir}/kind" ]] && [[ -f "${KUBECONFIG}" ]]; then
      "${demo_dir}/kind" delete cluster --name diracx-demo
  fi
  rm -rf "${tmp_dir}"
}

function check_hostname(){
  # Check that the hostname resolves to an IP address
  # dig doesn't consider the effect of /etc/hosts so we use ping instead
  ip_address=$(ping -c 1 "$1" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
  if [[ $? != 0 ]]; then
    printf "%b ping command exited with a non-zero exit code\n" ${SKULL_EMOJI}
    return 1
  fi
  if [[ -z "${ip_address}" ]]; then
    printf "%b No IP address found hostname %s\n" ${SKULL_EMOJI} "${1}"
    return 1
  fi
  if [[ "${ip_address}" == 127.* ]]; then
    printf "%b Hostname %s resolves to 127.0.0.1 but this is not supported\n" ${SKULL_EMOJI} "${1}"
    return 1
  fi
}

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <diracx_src_dir> [other source directories]"
  exit 1
fi
diracx_repo_dir="$(readlink -f "${1}")"
diracx_src_dir="${diracx_repo_dir}/src/diracx"
if [[ ! -d "${diracx_src_dir}" ]]; then
  printf "\U26A0\UFE0F Error: %s is not a clone of DiracX!" "${diracx_repo_dir}"
  exit 1
fi

declare -a pkg_dirs
declare -a pkg_names
for src_dir in "$@"; do
  for pkg_dir in $(find "$src_dir/src" -type f -mindepth 2 -maxdepth 2 -name '__init__.py'); do
    pkg_dirs+=("$(dirname "${pkg_dir}")")
    pkg_name="$(basename "$(dirname "${pkg_dir}")")"
    if [[ ${pkg_names[@]} =~ "$pkg_name" ]]; then
      printf "\U26A0\UFE0F Error: Source directory for %s was given twice!\n" "${pkg_name}"
      exit 1
    fi
    pkg_names+=("${pkg_name}")
  done
done
printf "%b Found package directories for: " ${UNICORN_EMOJI}
echo "${pkg_names[@]}"

machine_hostname=$(hostname | tr '[:upper:]' '[:lower:]')
if ! check_hostname "${machine_hostname}"; then
  machine_system=$(uname -s)
  machine_hostname=$(ifconfig | grep 'inet ' | grep -v '127' | awk '{ print $2 }' | head -n 1 | cut -d '/' -f 1)
  if ! check_hostname "${machine_hostname}"; then
    echo "Failed to find an appropriate hostname for the demo."
    exit 1
  fi
fi

trap "cleanup" EXIT

if [[ ! -f "${demo_dir}/helm" ]]; then
  # Inspect the current system
  system_name=$(uname -s | tr '[:upper:]' '[:lower:]')
  system_arch=$(uname -m)
  if [[ "${system_arch}" == "x86_64" ]]; then
      system_arch="amd64"
  fi

  # Download kind
  printf "%b Downloading kind\n" ${UNICORN_EMOJI}
  curl --no-progress-meter -L "https://kind.sigs.k8s.io/dl/v0.19.0/kind-${system_name}-${system_arch}" > "${demo_dir}/kind"

  # Download kubectl
  printf "%b Downloading kubectl\n" ${UNICORN_EMOJI}
  latest_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
  curl --no-progress-meter -L "https://dl.k8s.io/release/${latest_version}/bin/${system_name}/${system_arch}/kubectl" > "${demo_dir}/kubectl"

  # Download helm
  printf "%b Downloading helm\n" ${UNICORN_EMOJI}
  curl --no-progress-meter -L "https://get.helm.sh/helm-v3.12.0-${system_name}-${system_arch}.tar.gz" > "${tmp_dir}/helm.tar.gz"
  mkdir -p "${tmp_dir}/helm-tarball"
  tar xzf "${tmp_dir}/helm.tar.gz" -C "${tmp_dir}/helm-tarball"
  mv "${tmp_dir}/helm-tarball/${system_name}-${system_arch}/helm" "${demo_dir}"

  # Make the binaries executable
  chmod +x "${demo_dir}/kubectl" "${demo_dir}/kind" "${demo_dir}/helm"

  # Install helm plugins to ${HELM_DATA_HOME}
  "${demo_dir}/helm" plugin install https://github.com/databus23/helm-diff
fi

printf "%b Generating Kind cluster template...\n" ${UNICORN_EMOJI}
cp "${script_dir}/demo/demo_cluster_conf.tpl.yaml" "${demo_dir}/demo_cluster_conf.yaml"
for pkg_dir in "${pkg_dirs[@]}"; do
  mv "${demo_dir}/demo_cluster_conf.yaml" "${demo_dir}/demo_cluster_conf.yaml.bak"
  sed "s@{{ hostPaths }}@  - hostPath: ${pkg_dir}\n    containerPath: /diracx_source/$(basename "${pkg_dir}")\n{{ hostPaths }}@g" "${demo_dir}/demo_cluster_conf.yaml.bak" > "${demo_dir}/demo_cluster_conf.yaml"
done
mv "${demo_dir}/demo_cluster_conf.yaml" "${demo_dir}/demo_cluster_conf.yaml.bak"
sed "s@{{ hostPaths }}@@g" "${demo_dir}/demo_cluster_conf.yaml.bak" > "${demo_dir}/demo_cluster_conf.yaml"
if grep '{{' "${demo_dir}/demo_cluster_conf.yaml"; then
  printf "%b Error generating Kind template. Found {{ in the template result\n" ${UNICORN_EMOJI}
  exit 1
fi

printf "%b Starting Kind cluster...\n" ${UNICORN_EMOJI}
"${demo_dir}/kind" create cluster \
  --kubeconfig "${KUBECONFIG}" \
  --wait "1m" \
  --config "${demo_dir}/demo_cluster_conf.yaml" \
  --name diracx-demo

# Uncomment that to work fully offline
# We do not keep it because it increases the start time by 2mn
#
# printf "%b Loading images from docker to Kind...\n" ${UNICORN_EMOJI}
# declare -a image_names
# image_names+=("registry.k8s.io/ingress-nginx/controller:v1.8.0")
# image_names+=("ghcr.io/diracgrid/diracx/server:latest")
# image_names+=("ghcr.io/dexidp/dex:v2.36.0")
# for image_name in "${image_names[@]}"; do
#   docker pull "${image_name}"
#   "${demo_dir}/kind" --name diracx-demo load docker-image "${image_name}"
# done

printf "%b Creating an ingress...\n" ${UNICORN_EMOJI}
"${demo_dir}/kubectl" apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
printf "%b Waiting for ingress controller to be created...\n" ${UNICORN_EMOJI}
"${demo_dir}/kubectl" wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

printf "%b Generating Helm templates\n" ${UNICORN_EMOJI}
sed "s/{{ hostname }}/${machine_hostname}/g" "${script_dir}/demo/values.tpl.yaml" > "${demo_dir}/values.yaml"
if grep '{{' "${demo_dir}/values.yaml"; then
  printf "%b Error generating template. Found {{ in the template result\n" ${UNICORN_EMOJI}
  exit 1
fi

printf "%b Installing DiracX...\n" ${UNICORN_EMOJI}
"${demo_dir}/helm" install diracx-demo "${script_dir}/diracx" --values "${demo_dir}/values.yaml"
printf "%b Waiting for installation to finish...\n" ${UNICORN_EMOJI}
if "${demo_dir}/kubectl" wait --for=condition=ready pod --selector=app.kubernetes.io/name=diracx --timeout=300s; then
  printf "\U1F389 \U1F389 \U1F389 Pods are ready! \U1F389 \U1F389 \U1F389\n"
else
  printf "%b Installation did not start sucessfully!\n" ${SKULL_EMOJI}
fi

echo ""
printf "\U2139\UFE0F  To interact with the cluster:\n"
echo "export KUBECONFIG=${KUBECONFIG}"
echo "export HELM_DATA_HOME=${HELM_DATA_HOME}"
echo "export PATH=\${PATH}:${demo_dir}"
echo ""
printf "\U2139 \UFE0F You can access swagger at http://%s:8000/docs\n" "${machine_hostname}"
echo "To login, use the OAuth Authroization Code flow, and enter the following credentials"
echo "in the DEX web interface"
echo "Username: admin@example.com"
echo "Password: password"
echo ""
printf "\U2139\UFE0F  Press Ctrl+C to clean up and exit\n"

while true; do
  sleep 60;
  if ! check_hostname "${machine_hostname}"; then
    echo "The demo will likely need to be restarted."
  fi
done
