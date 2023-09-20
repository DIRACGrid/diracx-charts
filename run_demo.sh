#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

UNICORN_EMOJI='\xF0\x9F\xA6\x84'
SKULL_EMOJI='\xF0\x9F\x92\x80'
PARTY_EMOJI='\xF0\x9F\x8E\x89'
INFO_EMOJI='\xE2\x84\xB9\xEF\xB8\x8F'
WARN_EMOJI='\xE2\x9A\xA0\xEF\xB8\x8F'

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
  if ! ip_address=$(ping -c 1 "$1" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1); then
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

usage="${0##*/} [-h|--help] [--exit-when-done] [--] <diracx_src_dir> [other source directories]"

# Parse command-line switches
exit_when_done=0
while [ -n "${1:-}" ]; do case $1 in
	# Print a brief usage summary and exit
	-h|--help|-\?)
		printf 'Usage: %s\n' "$usage"
		exit ;;

	# # Unbundle short options
	# -[niladic-short-opts]?*)
	# 	tail="${1#??}"
	# 	head=${1%"$tail"}
	# 	shift
	# 	set -- "$head" "-$tail" "$@"
	# 	continue ;;

	# # Expand parametric values
	# -[monadic-short-opts]?*|--[!=]*=*)
	# 	case $1 in
	# 		--*) tail=${1#*=}; head=${1%%=*} ;;
	# 		*)   tail=${1#??}; head=${1%"$tail"} ;;
	# 	esac
	# 	shift
	# 	set -- "$head" "$tail" "$@"
	# 	continue ;;

	# Add new switch checks here
	--exit-when-done)
    exit_when_done=1;
		shift
		break ;;

	# Double-dash: Terminate option parsing
	--)
		shift
		break ;;

	# Invalid option: abort
	--*|-?*)
		>&2 printf '%b %s: Invalid option: "%s"\n' ${SKULL_EMOJI} "${0##*/}" "$1"
		>&2 printf 'Usage: %s\n' "$usage"
		exit 1 ;;

	# Argument not prefixed with a dash
	*) break ;;

esac; shift
done

# Remaining arguments are positional parameters that are used to specify which
# source directories to mount in the demo cluster
declare -a pkg_dirs=()
declare -a pkg_names=()
for src_dir in "$@"; do
  pkg_dirs+=("${src_dir}")
  # shellcheck disable=SC2044
  for pkg_dir in $(find "$src_dir/src" -mindepth 2 -maxdepth 2 -type f -name '__init__.py'); do
    pkg_name="$(basename "$(dirname "${pkg_dir}")")"

    # Check for the presence of $pkg_name in pkg_names array
    found=0
    if [ ${#pkg_names[@]} -gt 0 ]; then
      for existing_pkg_name in "${pkg_names[@]}"; do
        if [[ "$existing_pkg_name" == "$pkg_name" ]]; then
          found=1
          break
        fi
      done
    fi

    if [[ $found -eq 1 ]]; then
      printf "%b Error: Source directory for %s was given twice!\n" "${SKULL_EMOJI}" "${pkg_name}"
      exit 1
    fi
    pkg_names+=("${pkg_name}")
  done
done
if [ ${#pkg_names[@]} -gt 0 ]; then
  printf "%b Found package directories for: %s\n" ${UNICORN_EMOJI} "${pkg_names[@]}"
else
  printf "%b No source directories were specified\n" ${UNICORN_EMOJI}
fi

# Try to find a suitable hostname/IP-address for the demo. This must be not
# resolve to a loopback address as pods need to be able to communicate with
# each other via this address. For example, the DiracX service pod needs to be
# able to communicate with dex via this while users also use the same
# address/IP-address.
machine_hostname=$(hostname | tr '[:upper:]' '[:lower:]')
if ! check_hostname "${machine_hostname}"; then
  machine_hostname=$(ifconfig | grep 'inet ' | awk '{ print $2 }' | grep -v '^127' | head -n 1 | cut -d '/' -f 1)
  if ! check_hostname "${machine_hostname}"; then
    echo "Failed to find an appropriate hostname for the demo."
    exit 1
  fi
  printf "%b Using IP address %s instead \n" ${INFO_EMOJI} "${machine_hostname}"
fi

trap "cleanup" EXIT

# We download kind/kubectl/helm into the .demo directory to avoid having any
# requirements on the user's machine
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

# Generate the cluster template for kind which includes the source directories
printf "%b Generating Kind cluster template...\n" ${UNICORN_EMOJI}
cp "${script_dir}/demo/demo_cluster_conf.tpl.yaml" "${demo_dir}/demo_cluster_conf.yaml"
if [ ${#pkg_dirs[@]} -gt 0 ]; then
  for pkg_dir in "${pkg_dirs[@]}"; do
    mv "${demo_dir}/demo_cluster_conf.yaml" "${demo_dir}/demo_cluster_conf.yaml.bak"
    sed "s@{{ hostPaths }}@  - hostPath: ${pkg_dir}\n    containerPath: /diracx_source/$(basename "${pkg_dir}")\n{{ hostPaths }}@g" "${demo_dir}/demo_cluster_conf.yaml.bak" > "${demo_dir}/demo_cluster_conf.yaml"
  done
fi
mv "${demo_dir}/demo_cluster_conf.yaml" "${demo_dir}/demo_cluster_conf.yaml.bak"
sed "s@{{ hostPaths }}@@g" "${demo_dir}/demo_cluster_conf.yaml.bak" > "${demo_dir}/demo_cluster_conf.yaml"
if grep '{{' "${demo_dir}/demo_cluster_conf.yaml"; then
  printf "%b Error generating Kind template. Found {{ in the template result\n" ${UNICORN_EMOJI}
  exit 1
fi

# Generate the Helm values file
printf "%b Generating Helm templates\n" ${UNICORN_EMOJI}
sed "s/{{ hostname }}/${machine_hostname}/g" "${script_dir}/demo/values.tpl.yaml" > "${demo_dir}/values.yaml"
mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"
json="["
if [ ${#pkg_names[@]} -gt 0 ]; then
  for pkg_name in "${pkg_names[@]}"; do
      json+="\"$pkg_name\","
  done
fi
json="${json%,}]"
sed "s/{{ modules_to_mount }}/${json}/g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
if grep '{{' "${demo_dir}/values.yaml"; then
  printf "%b Error generating template. Found {{ in the template result\n" ${SKULL_EMOJI}
  exit 1
fi

# Create the cluster itself
printf "%b Starting Kind cluster...\n" ${UNICORN_EMOJI}
"${demo_dir}/kind" create cluster \
  --kubeconfig "${KUBECONFIG}" \
  --wait "1m" \
  --config "${demo_dir}/demo_cluster_conf.yaml" \
  --name diracx-demo

# Add an ingress to the cluster
printf "%b Creating an ingress...\n" ${UNICORN_EMOJI}
"${demo_dir}/kubectl" apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
printf "%b Waiting for ingress controller to be created...\n" ${UNICORN_EMOJI}
"${demo_dir}/kubectl" wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Install the DiracX chart
printf "%b Installing DiracX...\n" ${UNICORN_EMOJI}
if ! "${demo_dir}/helm" install diracx-demo "${script_dir}/diracx" --values "${demo_dir}/values.yaml"; then
  printf "%b Error using helm DiracX\n" ${WARN_EMOJI}
  echo "Failed to run \"helm install\"" >> "${demo_dir}/.failed"
else
  printf "%b Waiting for installation to finish...\n" ${UNICORN_EMOJI}
  if "${demo_dir}/kubectl" wait --for=condition=ready pod --selector=app.kubernetes.io/name=diracx --timeout=300s; then
    printf "%b %b %b Pods are ready! %b %b %b\n" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}"
    touch "${demo_dir}/.success"

    echo ""
    printf "%b  To interact with the cluster:\n" "${INFO_EMOJI}"
    echo "export KUBECONFIG=${KUBECONFIG}"
    echo "export HELM_DATA_HOME=${HELM_DATA_HOME}"
    echo "export PATH=\${PATH}:${demo_dir}"
    echo ""
    printf "%b  You can access swagger at http://%s:8000/docs\n" "${INFO_EMOJI}" "${machine_hostname}"
    echo "To login, use the OAuth Authroization Code flow, and enter the following credentials"
    echo "in the DEX web interface"
    echo "Username: admin@example.com"
    echo "Password: password"
  else
    printf "%b Installation did not start sucessfully!\n" ${WARN_EMOJI}
    echo "Installation did not start sucessfully!" >> "${demo_dir}/.failed"
  fi
fi

# Exit if --exit-when-done was passed
if [ ${exit_when_done} -eq 1 ]; then
  # Remove the EXIT trap so we don't clean up
  trap - EXIT
  exit 0
fi

echo ""
printf "%b  Press Ctrl+C to clean up and exit\n" "${INFO_EMOJI}"

while true; do
  sleep 60;
  # If the machine hostname changes then the demo will need to be restarted.
  # See the original machine_hostname detection description above.
  if ! check_hostname "${machine_hostname}"; then
    echo "The demo will likely need to be restarted."
  fi
done
