import requests
import json
import os
import time
import logging
import yaml

from typing import List, Dict, Optional
from pydantic import BaseModel, field_validator, RootModel


class User(BaseModel):
    """User to create."""
    username: str
    password: str
    given_name: Optional[str] = None
    family_name: Optional[str] = None

    @field_validator('given_name', mode='before')
    @classmethod
    def set_given_name(cls, v, values):
        # Use the username to set the given_name if it's not provided
        if v is None and values.data and 'username' in values.data:
            return values.data['username'].capitalize()
        return v

    @field_validator('family_name', mode='before')
    @classmethod
    def set_family_name(cls, v):
        # Set the family_name to an empty string if it's not provided
        return v or ""


class Client(BaseModel):
    """Client to create/update."""
    id: Optional[str] = None
    secret: Optional[str] = None
    name: str
    grant_types: Optional[List[str]] = []
    scope: Optional[List[str]] = []
    redirect_uris: Optional[List[str]] = []

    @field_validator('redirect_uris', mode='before')
    @classmethod
    def set_redirect_uris(cls, v, values):
        # redirect_uris is required if grant_types contains "authorization_code" or "device_code"
        grant_types = values.data.get('grant_types', []) if values.data else []
        if not v and ('authorization_code' in grant_types or \
                'urn:ietf:params:oauth:grant-type:device_code' in grant_types):
            raise ValueError("redirect_uris is required")
        return v


class InitialClient(Client):
    """Initial client used to get an admin token and modify the IAM instance."""
    id: str
    grant_types: Optional[List[str]] = ["client_credentials"]
    scope: Optional[List[str]] = ["scim:read", "scim:write", "iam:admin.read", "iam:admin.write"]


class Group(RootModel[Dict[str, List[str]]]):
    """Group to create."""
    root: Dict[str, List[str]]


class Config(BaseModel):
    issuer: str
    admin_user: User
    initial_client: InitialClient
    users: Optional[List[User]] = []
    clients: Optional[List[Client]] = []
    groups: Optional[Dict[str, Group]] = {}


def prepare_iam_instance(config_path):
    """Prepare the IAM instance
    """
    try:
        # Load and parse the configuration using Pydantic
        with open(config_path, 'r') as file:
            config_data = yaml.safe_load(file)
        config = Config.model_validate(config_data)
    except FileNotFoundError:
        logging.error("Config file not found")
        raise RuntimeError("Config file not found")
    except ValueError as e:
        logging.error(f"Error parsing config file: {e}")
        raise RuntimeError(f"Error parsing config file: {e}")
    except Exception as e:
        logging.error(f"Error parsing config file: {e}")
        raise RuntimeError(f"Error parsing config file: {e}")

    issuer = config.issuer

    logging.info("Getting an IAM admin token")
    # It sometimes takes a while for IAM to be ready so wait for a while if needed
    for _ in range(5):
        try:
            tokens = _get_iam_token(issuer, config.initial_client)
            break
        except requests.ConnectionError:
            logging.exception("Failed to connect to IAM, will retry in 10 seconds")
            time.sleep(5)
    else:
        raise RuntimeError("All attempts to _get_iam_token failed")
    initial_admin_access_token = tokens.get("access_token")

    logging.info("Updating IAM initial client")
    _create_or_update_iam_client(issuer, initial_admin_access_token, config.initial_client)
    # We need to fetch a new token as the scope has probably changed
    tokens = _get_iam_token(issuer, config.initial_client)
    admin_access_token = tokens.get("access_token")

    logging.info("Creating IAM clients")
    for client in config.clients:
        _create_or_update_iam_client(issuer, admin_access_token, client)

    logging.info("Creating IAM users")
    user_ids = {}
    for user in config.users:
        logging.info("Adding user %s" % user.username)
        user_config = _create_iam_user(issuer, admin_access_token, user)
        user_ids[user.username] = user_config["id"]

    logging.info("Creating IAM groups")
    # Groups
    for group_name, group_details in config.groups.items():
        group_config = _create_iam_group(issuer, admin_access_token, group_name)
        group_id = group_config["id"]

        # Subgroups
        for subgroup_name, users in group_details.root.items():
            subgroup_config = _create_iam_subgroup(issuer, admin_access_token, group_name, group_id, subgroup_name)
            subgroup_id = subgroup_config["id"]

            # Subgroups membership
            for username in users:
                _create_iam_group_membership(
                    issuer,
                    admin_access_token,
                    username,
                    user_ids[username],
                    group_id,
                )
                _create_iam_group_membership(
                    issuer,
                    admin_access_token,
                    username,
                    user_ids[username],
                    subgroup_id,
                )


def _get_iam_token(issuer: str, client: Client) -> dict:
    """Get a token using the client credentials flow"""
    query = os.path.join(issuer, "token")
    params = {"grant_type": "client_credentials"}
    response = requests.post(
        query,
        auth=(client.id, client.secret),
        params=params,
        timeout=5,
    )
    if not response.ok:
        logging.error(f"Failed to get an admin token: {response.status_code} {response.reason}")
        raise RuntimeError("Failed to get an admin token")
    return response.json()


def _create_or_update_iam_client(
    issuer: str,
    admin_access_token: str,
    client: Client,
) -> dict:
    """Generate an IAM client"""
    headers = {
        "Authorization": f"Bearer {admin_access_token}",
        "Content-Type": "application/json",
    }
    if client.id:
        logging.info(f"Client {client.name} seems to exist, let's try to update it")

        # Get the configuration of the client
        query = os.path.join(issuer, "iam/api/clients", client.id)
        response = requests.get(
            query,
            headers=headers,
            timeout=5,
        )
        if not response.ok:
            logging.error(
                f"Failed to get config for client {client.name}: {response.status_code} {response.reason}"
            )
            raise RuntimeError(f"Failed to get config for client {client.name}")

        # Update the configuration with the provided values
        client_config = response.json()
        client_config["client_name"] = client.name
        client_config["scope"] = ' '.join(client.scope)
        client_config["grant_types"] = client.grant_types
        client_config["redirect_uris"] = client.redirect_uris
        client_config["code_challenge_method"] = "S256"
        if not client.secret:
            client_config["token_endpoint_auth_method"] = "none"

        # Update the client
        response = requests.put(
            query,
            headers=headers,
            data=json.dumps(client_config),
            timeout=5,
        )
        if not response.ok:
            logging.error(
                f"Failed to update config for client {client.name}: {response.status_code} {response.reason}"
            )
            raise RuntimeError(f"Failed to update config for client {client.name}")
        return response.json()

    # Create the client
    logging.info(f"Creating client {client.name}")

    query = os.path.join(issuer, "iam/api/client-registration")
    client_config = {
        "client_name": client.name,
        "scope": ' '.join(client.scope),
        "grant_types": client.grant_types,
        "redirect_uris": client.redirect_uris,
        "token_endpoint_auth_method": "none",
        "code_challenge_method": "S256",
        "response_types": ["code"],
    }

    response = requests.post(
        query,
        headers=headers,
        data=json.dumps(client_config),
        timeout=5,
    )
    if not response.ok:
        logging.error(
            f"Failed to create client {client.name}: {response.status_code} {response.reason}"
        )
        raise RuntimeError(f"Failed to create client {client.name}")

    return response.json()

def _create_iam_user(issuer: str, admin_access_token: str, user: User) -> dict:
    """Generate an IAM user"""
    logging.info(f"Creating user {user.username}")

    query = os.path.join(issuer, "scim/Users")
    headers = {
        "Authorization": f"Bearer {admin_access_token}",
        "Content-Type": "application/scim+json",
    }

    user_config = {
        "active": True,
        "userName": user.username,
        "password": user.password,
        "name": {
            "givenName": user.given_name,
            "familyName": user.family_name,
            "formatted": f"{user.given_name} {user.family_name}",
        },
        "emails": [
            {
                "type": "work",
                "value": f"{user.given_name}.{user.family_name}@donotexist.email",
                "primary": True,
            }
        ],
    }

    response = requests.post(
        query,
        headers=headers,
        data=json.dumps(user_config),
        timeout=5,
    )
    if not response.ok:
        logging.error(
            f"Failed to create user {user.username}: {response.status_code} {response.reason}"
        )
        raise RuntimeError(f"Failed to create user {user.username}")
    return response.json()


def _create_iam_group(issuer: str, admin_access_token: str, group_name: str) -> dict:
    """Generate an IAM group"""
    logging.info(f"Creating group {group_name}")

    query = os.path.join(issuer, "scim/Groups")
    headers = {
        "Authorization": f"Bearer {admin_access_token}",
        "Content-Type": "application/scim+json",
    }
    group_config = {"schemas": ["urn:ietf:params:scim:schemas:core:2.0:Group"], "displayName": group_name}

    response = requests.post(
        query,
        headers=headers,
        data=json.dumps(group_config),
        timeout=5,
    )
    if not response.ok:
        logging.error(
            f"Failed to create group {group_name}: {response.status_code} {response.reason}"
        )
        raise RuntimeError(f"Failed to create group {group_name}")
    return response.json()


def _create_iam_subgroup(
    issuer: str, admin_access_token: str, group_name: str, group_id: str, subgroup_name: str
) -> dict:
    """Generate an IAM subgroup"""
    logging.info(f"Creating subgroup {group_name}/{subgroup_name}")

    subgroup_config = {
        "schemas": ["urn:ietf:params:scim:schemas:core:2.0:Group", "urn:indigo-dc:scim:schemas:IndigoGroup"],
        "urn:indigo-dc:scim:schemas:IndigoGroup": {
            "parentGroup": {
                "display": group_name,
                "value": group_id,
                r"\$ref": os.path.join(issuer, "scim/Groups", group_id),
            },
        },
        "displayName": subgroup_name,
    }

    query = os.path.join(issuer, "scim/Groups")
    headers = {
        "Authorization": f"Bearer {admin_access_token}",
        "Content-Type": "application/scim+json",
    }

    response = requests.post(
        query,
        headers=headers,
        data=json.dumps(subgroup_config),
        timeout=5,
    )
    if not response.ok:
        logging.error(
            f"Failed to create subgroup {group_name}/{subgroup_name}: {response.status_code} {response.reason}"
        )
        raise RuntimeError(f"Failed to create subgroup {group_name}/{subgroup_name}")
    return response.json()


def _create_iam_group_membership(
    issuer: str, admin_access_token: str, username: str, user_id: str, group_id: str
):
    """Bind a given user to some groups/subgroups"""
    membership_config = {
        "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "operations": [
            {
                "op": "add",
                "path": "members",
                "value": [
                    {"display": username, "value": user_id, r"\$ref": os.path.join(issuer, "scim/Users", user_id)}
                ],
            }
        ],
    }

    headers = {
        "Authorization": f"Bearer {admin_access_token}",
        "Content-Type": "application/scim+json",
    }
    query = os.path.join(issuer, "scim/Groups", group_id)

    response = requests.patch(
        query,
        headers=headers,
        data=json.dumps(membership_config),
        timeout=5,
    )
    if not response.ok:
        logging.error(
            f"Failed to add {username} to {group_id}: {response.status_code} {response.reason}"
        )
        raise RuntimeError(f"Failed to add {username} to {group_id}")

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    prepare_iam_instance(os.getenv("CONFIG_PATH"))
