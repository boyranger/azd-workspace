#!/usr/bin/env bash
set -euo pipefail

# check_status.sh
# Pemeriksaan status cepat untuk ZeroClaw yang dideploy ke Azure.
# Usage:
#  ./scripts/check_status.sh -g <RESOURCE_GROUP> [-a <CONTAINER_APP_NAME>] [-v <KEYVAULT_NAME>] [-d <DB_SECRET_NAME>] [-i] [-f]
# Options:
#  -g | --rg         : resource group (required)
#  -a | --app        : container app name (optional, otomatis cari jika tidak disediakan)
#  -v | --vault      : keyvault name (optional)
#  -d | --dbsecret   : secret name for DB connection in KeyVault (default: DATABASE_URL)
#  -i | --images     : show ACR image manifests
#  -l | --logs       : tail logs (will follow, ctrl-c to stop)
#  -f | --health     : try HTTP health checks against app FQDN

if ! command -v az >/dev/null 2>&1; then
  echo "Error: az (Azure CLI) tidak ditemukan." >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq tidak ditemukan." >&2
  exit 2
fi

RG=""
APP=""
VAULT=""
DB_SECRET_NAME="DATABASE_URL"
SHOW_IMAGES=false
TAIL_LOGS=false
HEALTH_CHECK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--rg) RG="$2"; shift 2 ;;
    -a|--app) APP="$2"; shift 2 ;;
    -v|--vault) VAULT="$2"; shift 2 ;;
    -d|--dbsecret) DB_SECRET_NAME="$2"; shift 2 ;;
    -i|--images) SHOW_IMAGES=true; shift 1 ;;
    -l|--logs) TAIL_LOGS=true; shift 1 ;;
    -f|--health) HEALTH_CHECK=true; shift 1 ;;
    -h|--help) sed -n '1,120p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

: "${RG:?Parameter -g/--rg required}"

echo "🔎 Checking resources in RG: $RG"

echo "-- Resources list --"
az resource list -g "$RG" --output table || true

# Find container app if not provided
if [ -z "$APP" ]; then
  echo "Mencari Container App 'zeroclaw' di RG..."
  APP=$(az containerapp list -g "$RG" --query "[?contains(tolower(name),'zeroclaw')].name | [0]" -o tsv)
fi

if [ -z "$APP" ]; then
  echo "Tidak menemukan Container App 'zeroclaw' di RG $RG" >&2
else
  echo "-- Container App: $APP --"
  az containerapp show -g "$RG" -n "$APP" -o json | jq '{name: .name, location: .location, image: .properties.template.containers[0].image, fqdn: .properties.configuration.ingress.fqdn, revisionMode: .properties.template.revisionMode, scale: .properties.template.scale}'

  FQDN=$(az containerapp show -g "$RG" -n "$APP" --query properties.configuration.ingress.fqdn -o tsv)
  IMAGE=$(az containerapp show -g "$RG" -n "$APP" --query properties.template.containers[0].image -o tsv)
  echo "FQDN: $FQDN"
  echo "Image: $IMAGE"

  echo "-- Revisions --"
  az containerapp revision list -g "$RG" -n "$APP" -o table || true
fi

# Health check
if [ "$HEALTH_CHECK" = true ] && [ -n "$FQDN" ]; then
  echo "-- Health checks for https://$FQDN --"
  for path in "/" "/health" "/ready"; do
    echo "GET $path"
    curl -sS -m 10 -o /dev/stderr -w "%{http_code}\n" "https://$FQDN$path" || echo "(no response)"
  done
fi

# Logs
if [ "$TAIL_LOGS" = true ] && [ -n "$APP" ]; then
  echo "-- Tailing logs (ctrl-c to stop) --"
  az containerapp logs show -g "$RG" -n "$APP" --follow
fi

# ACR / images
if [ "$SHOW_IMAGES" = true ]; then
  # try get ACR login server from subscription-level deployment outputs
  ACR=$(az deployment sub list --query "[?ends_with(name,'-deploy-')].properties.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT.value" -o tsv | head -n1 || true)
  if [ -z "$ACR" ]; then
    echo "ACR not found from latest deployments, trying to locate ACR in RG..."
    ACR=$(az acr list -g "$RG" --query "[0].loginServer" -o tsv)
  fi
  if [ -n "$ACR" ]; then
    ACR_NAME=${ACR%%.*}
    echo "-- ACR: $ACR_NAME ($ACR) --"
    az acr repository show-manifests -n "$ACR_NAME" --repository zeroclaw -o table || true
  else
    echo "ACR not found."
  fi
fi

# KeyVault secrets
if [ -n "$VAULT" ]; then
  echo "-- KeyVault secrets in $VAULT --"
  az keyvault secret list --vault-name "$VAULT" --query '[].{name:name,updated:attributes.updated}' -o table || true
  if [ -n "$DB_SECRET_NAME" ]; then
    echo "-- DB secret ($DB_SECRET_NAME) value (hidden) --"
    az keyvault secret show --vault-name "$VAULT" --name "$DB_SECRET_NAME" --query value -o tsv >/dev/null 2>&1 && echo "secret exists" || echo "not found or no access"
  fi
fi

# PostgreSQL
echo "-- PostgreSQL servers in RG --"
az resource list -g "$RG" --resource-type Microsoft.DBforPostgreSQL/flexibleServers -o table || true

# Monitoring / Insights
echo "-- Application Insights / Log Analytics in RG --"
az resource list -g "$RG" --query "[?contains(type,'components')||contains(type,'workspaces')].{name:name,type:type}" -o table || true

echo "✅ Done."
exit 0
