#!/bin/bash
set -euo pipefail
IFS=$'\n\t'


validate_email() {
    local email="$1"
    local email_regex="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$"

    if [[ $email =~ $email_regex ]]; then
        echo "Valid email address"
        return 0
    else
        echo "Invalid email address"
        exit 1
    fi
}

# Example usage:
read -r -p "Enter admin username: " dex_admin_username
read -r -p "Enter admin email: " dex_admin_email
validate_email "${dex_admin_email}"
read -r -s -p "Enter admin password: " dex_admin_password
echo
echo
# Generate the static client GUID for Dex
dex_client_uuid=$(uuidgen)

# Generate the admin account for dex
dex_admin_uuid=$(uuidgen)


# This is how dex generates the sub from a UserID
# https://github.com/dexidp/dex/issues/1719
dex_admin_sub=$(printf '\n$%s\x12\x05local' "${dex_admin_uuid}" | base64 -w 0)

dex_admin_hashed_password=$(htpasswd -bnBC 10 "" "${dex_admin_password}" | tr -d ':\n')


hostname="FIXME"

echo "Dex configuration for values.yaml"
echo

cat << EOF
dex:
  config:
    issuer: http://${hostname}:32002

    staticClients:
      - id: "${dex_client_uuid}"
        public: true
        name: "Diracx app"
        redirectURIs:
          - "https://${hostname}:8000/api/auth/device/complete"
          - "https://${hostname}:8000/api/auth/authorize/complete"

    staticPasswords:
      - email: "${dex_admin_email}"
        hash: "${dex_admin_hashed_password}"
        username: "${dex_admin_username}"
        userID: "${dex_admin_uuid}"
EOF


echo "Configuration to add in the DIRAC CS"
echo

cat << EOF
DiracX
{
 CsSync
  {
    VOs
    {
      dteam
      {
        DefaultGroup = admin
        IdP
        {
          ClientID = ${dex_client_uuid}
          URL = "http://${hostname}:32002"
        }
        UserSubjects
        {

          ${dex_admin_username} = ${dex_admin_sub}
        }
        Support
        {
        }
      }
    }
  }
}
EOF
