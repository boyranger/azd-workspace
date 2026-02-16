#!/usr/bin/env bash
set -euo pipefail

# deploy_aci.sh — build image into ACR and deploy to Azure Container Instances (ACI)
# Usage: ./scripts/deploy_aci.sh --rg <rg> --acr <acrName> [--location <location>] [--dns <dnsLabel>] [--tag <tag>]

RG=${RG:-zeroclaw-rg}
ACR_NAME=${ACR_NAME:-zeroclawacr}
IMAGE_TAG=${IMAGE_TAG:-latest}
LOCATION=${LOCATION:-eastasia}
DNS_LABEL=${DNS_LABEL:-zeroclaw-bot}
CONTAINER_NAME=${CONTAINER_NAME:-zeroclaw-gateway}

usage() {
  cat <<EOF
Usage: $0 --rg <resource-group> --acr <acr-name> [--location <location>] [--dns <dns-label>] [--tag <tag>]

Defaults:
  RG=${RG}  ACR=${ACR_NAME}  LOCATION=${LOCATION}  DNS_LABEL=${DNS_LABEL}  TAG=${IMAGE_TAG}
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rg) RG="$2"; shift 2 ;;
    --acr) ACR_NAME="$2"; shift 2 ;;
    --location) LOCATION="$2"; shift 2 ;;
    --dns) DNS_LABEL="$2"; shift 2 ;;
    --tag) IMAGE_TAG="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

# 1) Login & create RG + ACR (idempotent)
if ! az account show >/dev/null 2>&1; then
  echo "Please login to Azure (az login)" >&2
  az login
fi

az group create --name "$RG" --location "$LOCATION"
az acr create --resource-group "$RG" --name "$ACR_NAME" --sku Basic || true

# 2) Build & push image to ACR
ACR_LOGIN=$(az acr show -n "$ACR_NAME" -g "$RG" --query loginServer -o tsv)
if [ -z "$ACR_LOGIN" ]; then
  echo "Failed to get ACR login server" >&2
  exit 2
fi

echo "Building image: $ACR_LOGIN/zeroclaw:$IMAGE_TAG"
az acr build --registry "$ACR_NAME" --image "zeroclaw:$IMAGE_TAG" .

# 3) Deploy to ACI
ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" -g "$RG" --query "passwords[0].value" -o tsv)

az container create \
  --resource-group "$RG" \
  --name "$CONTAINER_NAME" \
  --image "$ACR_LOGIN/zeroclaw:$IMAGE_TAG" \
  --cpu 0.5 --memory 0.25 \
  --registry-login-server "$ACR_LOGIN" \
  --registry-username "$ACR_NAME" \
  --registry-password "$ACR_PASSWORD" \
  --dns-name-label "$DNS_LABEL" \
  --ports 8080 \
  --environment-variables ZEROCLAW_API_KEY="sk-..." ZEROCLAW_PROVIDER="openrouter" \
  --restart-policy Always \
  --location "$LOCATION"

FQDN=$(az container show --resource-group "$RG" --name "$CONTAINER_NAME" --query ipAddress.fqdn -o tsv)

echo "✅ Deployed: https://$FQDN"
