#!/usr/bin/env bash
set -euo pipefail

# maintenance.sh
# Maintenance helper for LiteLLM on Azure.
# Subcommands:
#   rotate-secrets   -- Rotate inline Container App secrets (master, salt, openai)
#   rotate-kv        -- Rotate secrets in KeyVault (then update Container App to use them)
#   update-image     -- Update container app to use a new image tag
#   scale            -- Update min/max replicas
#   db-backup        -- Run pg_dump backup using DATABASE_URL from KeyVault
# Usage examples:
#  ./scripts/maintenance.sh rotate-secrets -g RG -a APP --master NEWMASTER --salt NEWSALT --openai NEWOPENAI
#  ./scripts/maintenance.sh update-image -g RG -a APP -t v1.2.3 -r myregistry.azurecr.io/litellm
#  ./scripts/maintenance.sh scale -g RG -a APP --min 2 --max 4
#  ./scripts/maintenance.sh db-backup -g RG -v MYKV -d DATABASE_URL -o ./backups

if ! command -v az >/dev/null 2>&1; then
  echo "Error: az (Azure CLI) tidak ditemukan." >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq tidak ditemukan." >&2
  exit 2
fi

SUB=""
RG=""
APP=""
VAULT=""
DB_SECRET_NAME="DATABASE_URL"

subcommand="$1"; shift || (echo "No subcommand" && exit 1)

case "$subcommand" in
  rotate-secrets)
    # parse args
    MASTER=""; SALT=""; OPENAI=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -g|--rg) RG="$2"; shift 2 ;;
        -a|--app) APP="$2"; shift 2 ;;
        --master) MASTER="$2"; shift 2 ;;
        --salt) SALT="$2"; shift 2 ;;
        --openai) OPENAI="$2"; shift 2 ;;
        -h|--help) sed -n '1,160p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
      esac
    done
    : "${RG:?Parameter -g required}"; : "${APP:?Parameter -a required}"

    if [ -n "$MASTER" ]; then
      echo "Updating secret litellm-master-key on Container App $APP"
      az containerapp update -g "$RG" -n "$APP" --set properties.configuration.secrets[?name=='litellm-master-key'].value="$MASTER" || \
        az containerapp update -g "$RG" -n "$APP" --set properties.configuration.secrets[0].name='litellm-master-key' properties.configuration.secrets[0].value="$MASTER"
    fi
    if [ -n "$SALT" ]; then
      echo "Updating secret litellm-salt-key on Container App $APP"
      az containerapp update -g "$RG" -n "$APP" --set properties.configuration.secrets[?name=='litellm-salt-key'].value="$SALT" || \
        az containerapp update -g "$RG" -n "$APP" --set properties.configuration.secrets[1].name='litellm-salt-key' properties.configuration.secrets[1].value="$SALT"
    fi
    if [ -n "$OPENAI" ]; then
      echo "Updating secret openai-api-key on Container App $APP"
      az containerapp update -g "$RG" -n "$APP" --set properties.configuration.secrets[?name=='openai-api-key'].value="$OPENAI" || \
        az containerapp update -g "$RG" -n "$APP" --set properties.configuration.secrets[2].name='openai-api-key' properties.configuration.secrets[2].value="$OPENAI"
    fi
    echo "✅ Secrets updated. Consider restarting revisions if needed."
    ;;

  rotate-kv)
    # Rotate secrets in KeyVault, then update Container App inline secrets to new values
    NEW_MASTER=""; NEW_SALT=""; NEW_OPENAI="";
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -g|--rg) RG="$2"; shift 2 ;;
        -a|--app) APP="$2"; shift 2 ;;
        -v|--vault) VAULT="$2"; shift 2 ;;
        --master) NEW_MASTER="$2"; shift 2 ;;
        --salt) NEW_SALT="$2"; shift 2 ;;
        --openai) NEW_OPENAI="$2"; shift 2 ;;
        -h|--help) sed -n '1,220p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
      esac
    done
    : "${RG:?Parameter -g required}"; : "${APP:?Parameter -a required}"; : "${VAULT:?Parameter -v required}"

    if [ -n "$NEW_MASTER" ]; then
      az keyvault secret set --vault-name "$VAULT" --name LITELLM_MASTER_KEY --value "$NEW_MASTER"
      echo "Updated KeyVault secret LITELLM_MASTER_KEY"
      az containerapp update -g "$RG" -n "$APP" --set properties.configuration.secrets[?name=='litellm-master-key'].value="$NEW_MASTER" || true
    fi
    if [ -n "$NEW_SALT" ]; then
      az keyvault secret set --vault-name "$VAULT" --name LITELLM_SALT_KEY --value "$NEW_SALT"
      echo "Updated KeyVault secret LITELLM_SALT_KEY"
      az containerapp update -g "$RG" -n "$APP" --set properties.configuration.secrets[?name=='litellm-salt-key'].value="$NEW_SALT" || true
    fi
    if [ -n "$NEW_OPENAI" ]; then
      az keyvault secret set --vault-name "$VAULT" --name OPENAI_API_KEY --value "$NEW_OPENAI"
      echo "Updated KeyVault secret OPENAI_API_KEY"
      az containerapp update -g "$RG" -n "$APP" --set properties.configuration.secrets[?name=='openai-api-key'].value="$NEW_OPENAI" || true
    fi
    echo "✅ KeyVault secrets rotated and Container App inline secrets updated (if present)."
    ;;

  update-image)
    # Update the container app to use a new image: use fully qualified image URL or ACR + tag
    IMAGE="";
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -g|--rg) RG="$2"; shift 2 ;;
        -a|--app) APP="$2"; shift 2 ;;
        -t|--tag) TAG="$2"; shift 2 ;;
        -r|--registry) REPO="$2"; shift 2 ;;
        -h|--help) sed -n '1,300p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
      esac
    done
    : "${RG:?Parameter -g required}"; : "${APP:?Parameter -a required}"
    if [ -n "${REPO-}" ] && [ -n "${TAG-}" ]; then
      IMAGE="$REPO:$TAG"
    elif [ -n "${TAG-}" ]; then
      # try to determine ACR from deployment outputs
      ACR_LOGIN=$(az deployment sub list --query "[0].properties.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT.value" -o tsv || true)
      ACR_NAME=$(echo "$ACR_LOGIN" | cut -d'.' -f1)
      IMAGE="$ACR_LOGIN/litellm:$TAG"
    else
      echo "Provide --tag and optionally --registry"; exit 1
    fi
    echo "Updating Container App $APP image to $IMAGE"
    az containerapp update -g "$RG" -n "$APP" --image "$IMAGE"
    echo "✅ Image updated. New revisions will be created automatically."
    ;;

  scale)
    MIN=""; MAX=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -g|--rg) RG="$2"; shift 2 ;;
        -a|--app) APP="$2"; shift 2 ;;
        --min) MIN="$2"; shift 2 ;;
        --max) MAX="$2"; shift 2 ;;
        -h|--help) sed -n '1,360p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
      esac
    done
    : "${RG:?Parameter -g required}"; : "${APP:?Parameter -a required}"
    if [ -n "$MIN" ]; then
      az containerapp update -g "$RG" -n "$APP" --set properties.template.scale.minReplicas=$MIN
    fi
    if [ -n "$MAX" ]; then
      az containerapp update -g "$RG" -n "$APP" --set properties.template.scale.maxReplicas=$MAX
    fi
    echo "✅ Scaling updated"
    ;;

  db-backup)
    OUT_DIR="./backups"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -g|--rg) RG="$2"; shift 2 ;;
        -v|--vault) VAULT="$2"; shift 2 ;;
        -d|--dbsecret) DB_SECRET_NAME="$2"; shift 2 ;;
        -o|--outdir) OUT_DIR="$2"; shift 2 ;;
        -h|--help) sed -n '1,420p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
      esac
    done
    : "${VAULT:?Parameter -v required}"
    mkdir -p "$OUT_DIR"
    DBURL=$(az keyvault secret show --vault-name "$VAULT" --name "$DB_SECRET_NAME" --query value -o tsv)
    if [ -z "$DBURL" ]; then
      echo "Gagal dapatkan DATABASE_URL dari KeyVault $VAULT" >&2
      exit 1
    fi
    if ! command -v pg_dump >/dev/null 2>&1; then
      echo "pg_dump not found. Install postgresql client to run backup." >&2
      exit 2
    fi
    TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
    OUTFILE="$OUT_DIR/litellm-db-backup-$TIMESTAMP.dump"
    echo "Running pg_dump to $OUTFILE"
    pg_dump "$DBURL" -Fc -f "$OUTFILE"
    echo "✅ DB backup completed: $OUTFILE"
    ;;

  *)
    echo "Unknown subcommand: $subcommand"; exit 1 ;;
esac

exit 0
