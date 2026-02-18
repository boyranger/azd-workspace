#!/usr/bin/env basaph
set -euo pipefail

# deploy_azure.sh
# Skrip otomatis untuk:
#  - login ke Azure
#  - provisioning infra dengan Bicep (infra/main.bicep)
#  - build & push image ke ACR (menggunakan az acr build)
#  - update Azure Container App image dan menampilkan FQDN
#
# Usage:
#  ./scripts/deploy_azure.sh \
#    -s <SUBSCRIPTION_ID> \
#    -g <RESOURCE_GROUP_NAME> \
#    -l <LOCATION> \
#    -e <ENVIRONMENT_NAME> \
#    -t <IMAGE_TAG> \
#    [-x <EXTERNAL_DB_CONN_STRING>] \
#    [-o <OPENAI_API_KEY>] \
#    [--postgres] \
#    [--no-build] [--yes]

usage() {
  grep '^#' "$0" | sed -e 's/^#//'
  exit 1
}

if ! command -v az >/dev/null 2>&1; then
  echo "Error: az (Azure CLI) tidak ditemukan. Install terlebih dahulu: https://aka.ms/cli" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq tidak ditemukan. Install terlebih dahulu (apt/yum/brew)." >&2
  exit 2
fi

# Default values
NO_BUILD=false
ASSUME_YES=false
IMAGE_TAG="latest"
USE_SQLITE=true
ZEROCLAW_CONTAINER_APP_EXISTS="${ZEROCLAW_CONTAINER_APP_EXISTS:-false}"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--subscription) SUBSCRIPTION_ID="$2"; shift 2 ;;
    -g|--rg|--resource-group) RG_NAME="$2"; shift 2 ;;
    -l|--location) LOCATION="$2"; shift 2 ;;
    -e|--env|--environment) ENV_NAME="$2"; shift 2 ;;
    -t|--tag) IMAGE_TAG="$2"; shift 2 ;;
    -x|--external-db) EXTERNAL_DB_CONN="$2"; USE_SQLITE=false; shift 2 ;;
    -o|--openai) OPENAI_KEY="$2"; shift 2 ;;
    --postgres) USE_SQLITE=false; shift 1 ;;
    --no-build) NO_BUILD=true; shift 1 ;;
    --yes|-y) ASSUME_YES=true; shift 1 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

# Validate required args
: "${SUBSCRIPTION_ID:?Parameter -s/--subscription missing}"
: "${RG_NAME:?Parameter -g/--rg missing}"
: "${LOCATION:?Parameter -l/--location missing}"
: "${ENV_NAME:?Parameter -e/--env missing}"

# Utility
confirm() {
  if [ "$ASSUME_YES" = true ]; then
    return 0
  fi
  read -r -p "$1 [y/N]: " ans
  case "$ans" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

echo "🔧 Mulai proses deploy ZeroClaw ke Azure"

# Login if needed
if ! az account show >/dev/null 2>&1; then
  echo "az login..."
  az login
fi

echo "Set subscription: $SUBSCRIPTION_ID"
az account set --subscription "$SUBSCRIPTION_ID"

# Generate keys if not provided
if [ -z "${ZEROCLAW_MASTER_KEY-}" ]; then
  ZEROCLAW_MASTER_KEY=$(openssl rand -hex 16)
  echo "Generated ZEROCLAW_MASTER_KEY"
fi
if [ -z "${ZEROCLAW_SALT_KEY-}" ]; then
  ZEROCLAW_SALT_KEY=$(openssl rand -hex 16)
  echo "Generated ZEROCLAW_SALT_KEY"
fi

# If SQLite is disabled and no external DB is provided, provision Azure PostgreSQL.
if [ "$USE_SQLITE" = false ] && [ -z "${EXTERNAL_DB_CONN-}" ]; then
  if [ -z "${DB_ADMIN_PASS-}" ]; then
    echo "No external DB connection string provided. Azure PostgreSQL will be provisioned."
    if [ "$ASSUME_YES" = false ]; then
      read -r -s -p "Enter desired DB admin password (or press enter to auto-generate): " DB_ADMIN_PASS
      echo
    fi
    if [ -z "$DB_ADMIN_PASS" ]; then
      DB_ADMIN_PASS=$(openssl rand -base64 18)
      echo "Generated DB admin password"
    fi
  fi
fi

DEPLOY_NAME="zeroclaw-deploy-${ENV_NAME}-$(date +%s)"

echo "Menjalankan infra deployment (Bicep) dengan nama deployment: $DEPLOY_NAME"

PARAMS=(
  environmentName="$ENV_NAME"
  location="$LOCATION"
  resourceGroupName="$RG_NAME"
  zeroclawContainerAppExists="$ZEROCLAW_CONTAINER_APP_EXISTS"
  useSqlite="$USE_SQLITE"
  zeroclaw_master_key="$ZEROCLAW_MASTER_KEY"
  zeroclaw_salt_key="$ZEROCLAW_SALT_KEY"
)

if [ -n "${OPENAI_KEY-}" ]; then
  PARAMS+=(openai_api_key="$OPENAI_KEY")
fi
if [ -n "${EXTERNAL_DB_CONN-}" ]; then
  PARAMS+=(externalDatabaseConnectionString="$EXTERNAL_DB_CONN")
elif [ "$USE_SQLITE" = false ]; then
  PARAMS+=(databaseAdminPassword="$DB_ADMIN_PASS")
fi

# Convert params to az CLI format
AZ_PARAMS=()
for p in "${PARAMS[@]}"; do
  AZ_PARAMS+=(--parameters "$p")
done

# Run subscription-scoped deployment (main.bicep targetScope = 'subscription')
az deployment sub create --name "$DEPLOY_NAME" --location "$LOCATION" --template-file infra/main.bicep "${AZ_PARAMS[@]}"

# Get outputs
echo "Mengambil outputs deployment..."
outputs_json=$(az deployment sub show --name "$DEPLOY_NAME" --query properties.outputs -o json)
if [ -z "$outputs_json" ] || [ "$outputs_json" = "null" ]; then
  echo "Tidak ada outputs yang ditemukan. Henti." >&2
  exit 3
fi

ACR_LOGIN=$(echo "$outputs_json" | jq -r '.AZURE_CONTAINER_REGISTRY_ENDPOINT.value // empty')
if [ -z "$ACR_LOGIN" ]; then
  echo "Gagal mendapatkan ACR endpoint dari outputs. Pastikan deployment sukses." >&2
  echo "$outputs_json" | jq .
  exit 4
fi

ACR_NAME=${ACR_LOGIN%%.*}

echo "ACR login server: $ACR_LOGIN"
echo "ACR name: $ACR_NAME"

# Build & push image
if [ "$NO_BUILD" = false ]; then
echo "Membangun image dengan az acr build (image: $ACR_LOGIN/zeroclaw:$IMAGE_TAG)"
az acr build --registry "$ACR_NAME" --image "zeroclaw:$IMAGE_TAG" src/zeroclaw
else
  echo "--no-build: melewati build & push image"
fi

# Find the container app in the resource group
echo "Mencari Container App di resource group $RG_NAME..."
CONTAINER_APP=$(az containerapp list -g "$RG_NAME" --query "[?contains(tolower(name),'zeroclaw')].name | [0]" -o tsv)
if [ -z "$CONTAINER_APP" ]; then
  echo "Gagal menemukan Container App 'zeroclaw' di RG $RG_NAME" >&2
  exit 5
fi

echo "Container App: $CONTAINER_APP"

# Update container app image to the new tag
if [ "$NO_BUILD" = false ]; then
  echo "Mengupdate Container App image ke $ACR_LOGIN/zeroclaw:$IMAGE_TAG"
  az containerapp update --name "$CONTAINER_APP" --resource-group "$RG_NAME" --image "$ACR_LOGIN/zeroclaw:$IMAGE_TAG"
fi

# Get FQDN
FQDN=$(az containerapp show --name "$CONTAINER_APP" --resource-group "$RG_NAME" --query properties.configuration.ingress.fqdn -o tsv)

cat <<EOF
✅ Deploy selesai!
- Container App: $CONTAINER_APP
- URL: https://$FQDN
- ACR: $ACR_LOGIN
- DB mode: $( [ "$USE_SQLITE" = true ] && echo "sqlite (default)" || { [ -n "${EXTERNAL_DB_CONN-}" ] && echo "external"; } || echo "azure-postgresql" )
- Master key: $ZEROCLAW_MASTER_KEY
- Salt key: $ZEROCLAW_SALT_KEY

Tips:
- Untuk melihat logs: az containerapp logs show -n $CONTAINER_APP -g $RG_NAME --follow
- Untuk melihat status deployment: az deployment sub show --name $DEPLOY_NAME
EOF

exit 0
