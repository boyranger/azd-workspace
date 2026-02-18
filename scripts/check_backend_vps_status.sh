#!/usr/bin/env bash
set -euo pipefail

# check_backend_vps_status.sh
# Quick status check for Azure VPS backend resources.
# Usage:
#   ./scripts/check_backend_vps_status.sh --rg <resource-group> [--vm <vm-name>] [--func <function-app>] [--storage <storage-account>] [--container <blob-container>]

if ! command -v az >/dev/null 2>&1; then
  echo "Error: az (Azure CLI) tidak ditemukan." >&2
  exit 2
fi

RG_NAME=""
VM_NAME=""
FUNC_APP_NAME=""
STORAGE_ACCOUNT=""
ARCHIVE_CONTAINER="archive"

usage() {
  sed -n '1,60p' "$0"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rg|-g) RG_NAME="$2"; shift 2 ;;
    --vm) VM_NAME="$2"; shift 2 ;;
    --func) FUNC_APP_NAME="$2"; shift 2 ;;
    --storage) STORAGE_ACCOUNT="$2"; shift 2 ;;
    --container) ARCHIVE_CONTAINER="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

: "${RG_NAME:?Parameter --rg/-g required}"

echo "== Resource inventory ($RG_NAME) =="
az resource list -g "$RG_NAME" --query "[].{name:name,type:type,location:location}" -o table || true

if [ -z "$VM_NAME" ]; then
  VM_NAME=$(az vm list -g "$RG_NAME" --query "[0].name" -o tsv || true)
fi

if [ -n "$VM_NAME" ]; then
  echo
  echo "== VM status ($VM_NAME) =="
  az vm get-instance-view -g "$RG_NAME" -n "$VM_NAME" --query "{name:name,power:instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus|[0],provision:provisioningState}" -o json
  VM_PUBLIC_IP=$(az vm show -d -g "$RG_NAME" -n "$VM_NAME" --query publicIps -o tsv)
  echo "VM Public IP: $VM_PUBLIC_IP"
  echo "Try MQTT TLS check (from local):"
  echo "  openssl s_client -connect ${VM_PUBLIC_IP}:8883 -servername ${VM_PUBLIC_IP} -brief"
fi

if [ -z "$FUNC_APP_NAME" ]; then
  FUNC_APP_NAME=$(az functionapp list -g "$RG_NAME" --query "[0].name" -o tsv || true)
fi

if [ -n "$FUNC_APP_NAME" ]; then
  echo
  echo "== Function App status ($FUNC_APP_NAME) =="
  az functionapp show -g "$RG_NAME" -n "$FUNC_APP_NAME" --query "{name:name,state:state,host:defaultHostName,kind:kind}" -o json
fi

if [ -z "$STORAGE_ACCOUNT" ]; then
  STORAGE_ACCOUNT=$(az storage account list -g "$RG_NAME" --query "[0].name" -o tsv || true)
fi

if [ -n "$STORAGE_ACCOUNT" ]; then
  echo
  echo "== Storage status ($STORAGE_ACCOUNT) =="
  az storage account show -g "$RG_NAME" -n "$STORAGE_ACCOUNT" --query "{name:name,primaryLocation:primaryLocation,sku:sku.name,provisioningState:provisioningState}" -o json
  az storage container show --name "$ARCHIVE_CONTAINER" --account-name "$STORAGE_ACCOUNT" --auth-mode login --query "{name:name,lastModified:properties.lastModified}" -o json || echo "Container '$ARCHIVE_CONTAINER' not found"
fi

echo

echo "✅ Status check selesai."
