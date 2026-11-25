#!/bin/bash
set -euo pipefail

# Script to dump all secrets and configmaps from Kubernetes cluster
# Output will be saved to a timestamped directory

show_help() {
    cat << EOF
Usage: $0 --namespace NAMESPACE [OPTIONS]

Dump all secrets and configmaps from a Kubernetes namespace.

Required:
  --namespace NAME      Kubernetes namespace to dump resources from

Options:
  --output DIR          Output directory (default: k8s_dump_TIMESTAMP)
  --encrypt CERT        Path to X509 certificate in PEM format for encryption (creates single encrypted archive)
  --help               Show this help message and exit

Examples:
  # Dump to separate files
  $0 --namespace default

  # Dump to custom directory
  $0 --namespace default --output my_backup

  # Dump to encrypted archive
  $0 --namespace production --encrypt /path/to/cert.pem --output production_backup

EOF
    exit 0
}

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR=""
ENCRYPT_MODE=false
X509_CERT=""
NAMESPACE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            ;;
        --namespace|-n)
            if [ -z "${2:-}" ]; then
                echo "Error: --namespace requires a value"
                exit 1
            fi
            NAMESPACE="$2"
            shift 2
            ;;
        --output|-o)
            if [ -z "${2:-}" ]; then
                echo "Error: --output requires a value"
                exit 1
            fi
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --encrypt)
            ENCRYPT_MODE=true
            if [ -z "${2:-}" ]; then
                echo "Error: --encrypt requires a path to X509 certificate"
                exit 1
            fi
            X509_CERT="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set default output directory if not provided
if [ -z "${OUTPUT_DIR}" ]; then
    OUTPUT_DIR="k8s_dump_${TIMESTAMP}"
fi

# Validate required arguments
if [ -z "${NAMESPACE}" ]; then
    echo "Error: --namespace is required"
    echo "Use --help for usage information"
    exit 1
fi

# Validate encryption setup
if [ "${ENCRYPT_MODE}" = true ]; then
    if [ ! -f "${X509_CERT}" ]; then
        echo "Error: X509 certificate file not found: ${X509_CERT}"
        exit 1
    fi

    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        echo "Error: openssl is required for encryption but not found"
        exit 1
    fi

    # Verify the certificate is valid PEM format
    if ! openssl x509 -in "${X509_CERT}" -noout 2>/dev/null; then
        echo "Error: Invalid X509 certificate or not in PEM format: ${X509_CERT}"
        exit 1
    fi

    echo "Encryption mode enabled with certificate: ${X509_CERT}"
fi

echo "Creating output directory: ${OUTPUT_DIR}"

if [ "${ENCRYPT_MODE}" = true ]; then
    # For encrypted mode, create a temporary directory
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "${TEMP_DIR}"' EXIT
    WORK_DIR="${TEMP_DIR}"
else
    mkdir -p "${OUTPUT_DIR}"
    WORK_DIR="${OUTPUT_DIR}"
fi

echo "Processing namespace: ${NAMESPACE}"

# Dump secrets
echo "Dumping secrets (filtering for 'diracx' in name)..."
SECRETS=$(kubectl get secrets -n "${NAMESPACE}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -n "${SECRETS}" ]; then
    mkdir -p "${WORK_DIR}/secrets"
    for secret in ${SECRETS}; do
        if [[ "${secret}" == *"diracx"* ]]; then
            echo "  Exporting secret: ${secret}"
            kubectl get secret "${secret}" -n "${NAMESPACE}" -o yaml > "${WORK_DIR}/secrets/${secret}.yaml"
        fi
    done
    # Check if any files were created
    if [ ! "$(ls -A "${WORK_DIR}"/secrets 2>/dev/null)" ]; then
        echo "  No secrets with 'diracx' in name found"
        rmdir "${WORK_DIR}/secrets" 2>/dev/null || true
    fi
else
    echo "  No secrets found"
fi

# Dump configmaps
echo "Dumping configmaps (filtering for 'diracx' in name)..."
CONFIGMAPS=$(kubectl get configmaps -n "${NAMESPACE}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -n "${CONFIGMAPS}" ]; then
    mkdir -p "${WORK_DIR}/configmaps"
    for cm in ${CONFIGMAPS}; do
        if [[ "${cm}" == *"diracx"* ]]; then
            echo "  Exporting configmap: ${cm}"
            kubectl get configmap "${cm}" -n "${NAMESPACE}" -o yaml > "${WORK_DIR}/configmaps/${cm}.yaml"
        fi
    done
    # Check if any files were created
    if [ ! "$(ls -A "${WORK_DIR}"/configmaps 2>/dev/null)" ]; then
        echo "  No configmaps with 'diracx' in name found"
        rmdir "${WORK_DIR}/configmaps" 2>/dev/null || true
    fi
else
    echo "  No configmaps found"
fi

if [ "${ENCRYPT_MODE}" = true ]; then
    echo ""
    echo "Creating encrypted archive..."

    # Create tarball
    TARBALL="${OUTPUT_DIR}.tar.gz"
    tar -czf "${TARBALL}" -C "${TEMP_DIR}" .

    trap 'rm -r "${TARBALL}"' EXIT


    # Generate a random symmetric key
    SYMMETRIC_KEY=$(openssl rand -base64 32)

    # Encrypt the tarball with the symmetric key
    ENCRYPTED_FILE="${OUTPUT_DIR}.tar.gz.enc"
    echo "${SYMMETRIC_KEY}" | openssl enc -aes-256-cbc -salt -pbkdf2 -in "${TARBALL}" -out "${ENCRYPTED_FILE}" -pass stdin

    # Extract public key from X509 certificate and encrypt the symmetric key
    KEY_FILE="${OUTPUT_DIR}.key.enc"
    echo "${SYMMETRIC_KEY}" | openssl pkeyutl -encrypt -certin -inkey "${X509_CERT}" -out "${KEY_FILE}"
    rm -f "${TARBALL}"

    echo ""
    echo "==================================="
    echo "Encrypted dump completed!"
    echo "==================================="
    echo ""
    echo "Files created:"
    echo "  Encrypted data: ${ENCRYPTED_FILE}"
    echo "  Encrypted key:  ${KEY_FILE}"
    echo ""
    echo "To decrypt:"
    echo "  1. Decrypt the symmetric key (using the private key corresponding to the certificate):"
    echo "     openssl pkeyutl -decrypt -inkey /path/to/private.key -in ${KEY_FILE} -out ${OUTPUT_DIR}.key"
    echo "  2. Decrypt the archive:"
    echo "     openssl enc -aes-256-cbc -d -pbkdf2 -in ${ENCRYPTED_FILE} -out ${OUTPUT_DIR}.tar.gz -pass file:${OUTPUT_DIR}.key"
    echo "  3. Extract:"
    echo "     tar -xzf ${OUTPUT_DIR}.tar.gz"
else
    echo ""
    echo "==================================="
    echo "Dump completed successfully!"
    echo "Output directory: ${OUTPUT_DIR}"
    echo "==================================="
    echo ""
    echo "Summary:"
    echo "  Secrets: $(find "${OUTPUT_DIR}/secrets" -type f -name "*.yaml" 2>/dev/null | wc -l) files"
    echo "  ConfigMaps: $(find "${OUTPUT_DIR}/configmaps" -type f -name "*.yaml" 2>/dev/null | wc -l) files"
fi
