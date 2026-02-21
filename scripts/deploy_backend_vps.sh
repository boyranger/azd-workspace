#!/usr/bin/env bash
set -euo pipefail

# deploy_backend_vps.sh
# Provision backend MVP on Azure VPS using Azure CLI:
# - Resource Group
# - Networking (VNet/Subnet/NSG/Public IP/NIC)
# - Ubuntu 24 VM (Standard_B1s) + Mosquitto bootstrap via cloud-init
# - Storage Account + Blob container for cold archive
# - Function App (Consumption) for ingest/rules/archive workers
# - Optional IoT Hub (Free tier)
#
# Usage:
#   ./scripts/deploy_backend_vps.sh \
#     --subscription <SUBSCRIPTION_ID> \
#     [--rg <RESOURCE_GROUP>] \
#     [--location <LOCATION>] \
#     [--vm-name <VM_NAME>] \
#     [--vm-size <VM_SIZE>] \
#     [--admin-user <ADMIN_USER>] \
#     [--ssh-key <SSH_PUBLIC_KEY_PATH>] \
#     [--admin-cidr <CIDR_FOR_SSH>] \
#     [--mqtt-user <MQTT_USER>] \
#     [--mqtt-password <MQTT_PASSWORD>] \
#     [--enable-plain-mqtt] \
#     [--enable-websocket] \
#     [--create-iothub] \
#     [--yes]

if ! command -v az >/dev/null 2>&1; then
  echo "Error: az (Azure CLI) tidak ditemukan." >&2
  exit 2
fi

RG_NAME=${RG_NAME:-mqtt-saas-vm-rg-ea}
LOCATION=${LOCATION:-eastasia}
VM_NAME=${VM_NAME:-mqtt-saas-b1s}
VM_SIZE=${VM_SIZE:-Standard_B1s}
ADMIN_USER=${ADMIN_USER:-far-azd}
SSH_KEY_PATH=${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519.pub}
ADMIN_CIDR=${ADMIN_CIDR:-*}
VNET_NAME=${VNET_NAME:-${VM_NAME}-vnet}
SUBNET_NAME=${SUBNET_NAME:-${VM_NAME}-subnet}
NSG_NAME=${NSG_NAME:-${VM_NAME}-nsg}
PIP_NAME=${PIP_NAME:-${VM_NAME}-pip}
NIC_NAME=${NIC_NAME:-${VM_NAME}-nic}
FUNC_RUNTIME=${FUNC_RUNTIME:-python}
FUNC_RUNTIME_VERSION=${FUNC_RUNTIME_VERSION:-3.11}
ENABLE_PLAIN_MQTT=false
ENABLE_WEBSOCKET=false
CREATE_IOTHUB=false
ASSUME_YES=false
SUBSCRIPTION_ID=""
MQTT_USER=${MQTT_USER:-admin}
MQTT_PASSWORD=${MQTT_PASSWORD:-}

usage() {
  sed -n '1,80p' "$0"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription|-s) SUBSCRIPTION_ID="$2"; shift 2 ;;
    --rg|-g) RG_NAME="$2"; shift 2 ;;
    --location|-l) LOCATION="$2"; shift 2 ;;
    --vm-name) VM_NAME="$2"; shift 2 ;;
    --vm-size) VM_SIZE="$2"; shift 2 ;;
    --admin-user) ADMIN_USER="$2"; shift 2 ;;
    --ssh-key) SSH_KEY_PATH="$2"; shift 2 ;;
    --admin-cidr) ADMIN_CIDR="$2"; shift 2 ;;
    --mqtt-user) MQTT_USER="$2"; shift 2 ;;
    --mqtt-password) MQTT_PASSWORD="$2"; shift 2 ;;
    --enable-plain-mqtt) ENABLE_PLAIN_MQTT=true; shift 1 ;;
    --enable-websocket) ENABLE_WEBSOCKET=true; shift 1 ;;
    --create-iothub) CREATE_IOTHUB=true; shift 1 ;;
    --yes|-y) ASSUME_YES=true; shift 1 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

: "${SUBSCRIPTION_ID:?Parameter --subscription/-s required}"

if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "Error: SSH public key tidak ditemukan: $SSH_KEY_PATH" >&2
  echo "Generate key dulu: ssh-keygen -t ed25519 -C \"$ADMIN_USER@$VM_NAME\"" >&2
  exit 2
fi

if [ -z "$MQTT_PASSWORD" ]; then
  MQTT_PASSWORD=$(openssl rand -base64 18 | tr -d '\n')
fi

if ! az account show >/dev/null 2>&1; then
  echo "Error: belum login Azure. Jalankan: az login" >&2
  exit 2
fi
az account set --subscription "$SUBSCRIPTION_ID"

suffix=$(openssl rand -hex 3)
storage_base=$(echo "zc${VM_NAME}${suffix}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')
STORAGE_ACCOUNT=${STORAGE_ACCOUNT:-${storage_base:0:24}}
ARCHIVE_CONTAINER=${ARCHIVE_CONTAINER:-archive}
FUNC_APP_NAME=${FUNC_APP_NAME:-func-${VM_NAME}-${suffix}}
IOTHUB_NAME=${IOTHUB_NAME:-iothub-${VM_NAME}-${suffix}}

if [ ${#STORAGE_ACCOUNT} -lt 3 ]; then
  STORAGE_ACCOUNT="zc${suffix}store"
fi

if [ "$ASSUME_YES" = false ]; then
  cat <<PLAN
Plan deploy backend VPS:
- Subscription : $SUBSCRIPTION_ID
- ResourceGroup: $RG_NAME
- Location     : $LOCATION
- VM           : $VM_NAME ($VM_SIZE)
- Admin user   : $ADMIN_USER
- SSH source   : $ADMIN_CIDR
- MQTT user    : $MQTT_USER
- Storage      : $STORAGE_ACCOUNT
- Function App : $FUNC_APP_NAME
- IoT Hub      : $( [ "$CREATE_IOTHUB" = true ] && echo "create" || echo "skip" )
PLAN
  read -r -p "Lanjut deploy? [y/N]: " ans
  case "$ans" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Batal."; exit 0 ;;
  esac
fi

echo "[1/10] Create/ensure resource group"
az group create --name "$RG_NAME" --location "$LOCATION" >/dev/null

echo "[2/10] Create network"
az network vnet create \
  --resource-group "$RG_NAME" \
  --name "$VNET_NAME" \
  --address-prefixes 10.10.0.0/16 \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefixes 10.10.1.0/24 >/dev/null

az network nsg create --resource-group "$RG_NAME" --name "$NSG_NAME" --location "$LOCATION" >/dev/null

# Clean and recreate inbound rules to keep this script idempotent
for rule in allow-ssh allow-mqtt-plain allow-mqtt-tls allow-mqtt-ws; do
  az network nsg rule delete -g "$RG_NAME" --nsg-name "$NSG_NAME" -n "$rule" >/dev/null 2>&1 || true
done

az network nsg rule create \
  --resource-group "$RG_NAME" \
  --nsg-name "$NSG_NAME" \
  --name allow-ssh \
  --priority 1000 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes "$ADMIN_CIDR" \
  --destination-port-ranges 22 >/dev/null

if [ "$ENABLE_PLAIN_MQTT" = true ]; then
  az network nsg rule create \
    --resource-group "$RG_NAME" \
    --nsg-name "$NSG_NAME" \
    --name allow-mqtt-plain \
    --priority 1010 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes '*' \
    --destination-port-ranges 1883 >/dev/null
fi

az network nsg rule create \
  --resource-group "$RG_NAME" \
  --nsg-name "$NSG_NAME" \
  --name allow-mqtt-tls \
  --priority 1020 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes '*' \
  --destination-port-ranges 8883 >/dev/null

if [ "$ENABLE_WEBSOCKET" = true ]; then
  az network nsg rule create \
    --resource-group "$RG_NAME" \
    --nsg-name "$NSG_NAME" \
    --name allow-mqtt-ws \
    --priority 1030 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes '*' \
    --destination-port-ranges 9001 >/dev/null
fi

echo "[3/10] Create Public IP and NIC"
az network public-ip create \
  --resource-group "$RG_NAME" \
  --name "$PIP_NAME" \
  --sku Standard \
  --allocation-method Static >/dev/null

az network nic create \
  --resource-group "$RG_NAME" \
  --name "$NIC_NAME" \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME" \
  --network-security-group "$NSG_NAME" \
  --public-ip-address "$PIP_NAME" >/dev/null

TMP_CLOUD_INIT=$(mktemp)
cat > "$TMP_CLOUD_INIT" <<CLOUD
#cloud-config
package_update: true
package_upgrade: true
packages:
  - mosquitto
  - mosquitto-clients
  - openssl
  - ufw
  - fail2ban
write_files:
  - path: /etc/mosquitto/conf.d/saas.conf
    permissions: '0644'
    content: |
      # Keep core persistence settings from default mosquitto.conf.
      allow_anonymous false
      password_file /etc/mosquitto/passwd
      acl_file /etc/mosquitto/acl
      listener 1883 0.0.0.0
      listener 8883 0.0.0.0
      cafile /etc/mosquitto/certs/ca.crt
      certfile /etc/mosquitto/certs/server.crt
      keyfile /etc/mosquitto/certs/server.key
      require_certificate false
  - path: /etc/mosquitto/acl
    permissions: '0644'
    content: |
      user ${MQTT_USER}
      topic readwrite #
runcmd:
  - mkdir -p /etc/mosquitto/certs
  - if [ ! -f /etc/mosquitto/certs/ca.crt ]; then openssl req -x509 -nodes -newkey rsa:2048 -days 3650 -keyout /etc/mosquitto/certs/ca.key -out /etc/mosquitto/certs/ca.crt -subj "/CN=mqtt-saas-ca"; fi
  - if [ ! -f /etc/mosquitto/certs/server.crt ]; then openssl req -nodes -newkey rsa:2048 -keyout /etc/mosquitto/certs/server.key -out /tmp/server.csr -subj "/CN=${VM_NAME}"; fi
  - if [ ! -f /etc/mosquitto/certs/server.crt ]; then openssl x509 -req -in /tmp/server.csr -CA /etc/mosquitto/certs/ca.crt -CAkey /etc/mosquitto/certs/ca.key -CAcreateserial -out /etc/mosquitto/certs/server.crt -days 825; fi
  - chown root:mosquitto /etc/mosquitto/certs/server.key /etc/mosquitto/certs/server.crt /etc/mosquitto/certs/ca.crt
  - chmod 640 /etc/mosquitto/certs/server.key /etc/mosquitto/certs/server.crt /etc/mosquitto/certs/ca.crt
  - chmod 600 /etc/mosquitto/certs/ca.key
  - mosquitto_passwd -b -c /etc/mosquitto/passwd '${MQTT_USER}' '${MQTT_PASSWORD}'
  - chown root:mosquitto /etc/mosquitto/passwd /etc/mosquitto/acl
  - chmod 640 /etc/mosquitto/passwd /etc/mosquitto/acl
  - systemctl enable mosquitto
  - systemctl restart mosquitto
  - ufw allow OpenSSH
  - ufw allow 8883/tcp
  - ufw --force enable
CLOUD

echo "[4/10] Create VM"
az vm create \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --nics "$NIC_NAME" \
  --image Ubuntu2404 \
  --size "$VM_SIZE" \
  --admin-username "$ADMIN_USER" \
  --ssh-key-values "$SSH_KEY_PATH" \
  --custom-data "$TMP_CLOUD_INIT" >/dev/null

rm -f "$TMP_CLOUD_INIT"

echo "[5/10] Ensure Storage Account"
if ! az storage account show -g "$RG_NAME" -n "$STORAGE_ACCOUNT" >/dev/null 2>&1; then
  az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RG_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 >/dev/null
fi

echo "[6/10] Ensure Blob container"
az storage container create \
  --name "$ARCHIVE_CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login >/dev/null

echo "[7/10] Ensure Function App"
if ! az functionapp show -g "$RG_NAME" -n "$FUNC_APP_NAME" >/dev/null 2>&1; then
  az functionapp create \
    --resource-group "$RG_NAME" \
    --consumption-plan-location "$LOCATION" \
    --runtime "$FUNC_RUNTIME" \
    --runtime-version "$FUNC_RUNTIME_VERSION" \
    --functions-version 4 \
    --name "$FUNC_APP_NAME" \
    --storage-account "$STORAGE_ACCOUNT" \
    --os-type Linux >/dev/null
fi

echo "[8/10] Configure Function App settings"
VM_PUBLIC_IP=$(az vm show -d -g "$RG_NAME" -n "$VM_NAME" --query publicIps -o tsv)
az functionapp config appsettings set \
  --resource-group "$RG_NAME" \
  --name "$FUNC_APP_NAME" \
  --settings \
    MQTT_BROKER_HOST="$VM_PUBLIC_IP" \
    MQTT_BROKER_PORT="8883" \
    MQTT_BROKER_USERNAME="$MQTT_USER" \
    MQTT_BROKER_PASSWORD="$MQTT_PASSWORD" \
    MQTT_TOPIC_FILTER="#" \
    ARCHIVE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT" \
    ARCHIVE_BLOB_CONTAINER="$ARCHIVE_CONTAINER" >/dev/null

echo "[9/10] Optional IoT Hub"
if [ "$CREATE_IOTHUB" = true ]; then
  if ! az iot hub show -g "$RG_NAME" -n "$IOTHUB_NAME" >/dev/null 2>&1; then
    az iot hub create \
      --resource-group "$RG_NAME" \
      --name "$IOTHUB_NAME" \
      --location "$LOCATION" \
      --sku F1 \
      --partition-count 2 >/dev/null
  fi
fi

echo "[10/10] Summary"
VM_PUBLIC_IP=$(az vm show -d -g "$RG_NAME" -n "$VM_NAME" --query publicIps -o tsv)
FUNC_HOST=$(az functionapp show -g "$RG_NAME" -n "$FUNC_APP_NAME" --query defaultHostName -o tsv)

cat <<OUT
✅ Backend VPS deployed.
- Resource Group : $RG_NAME
- VM             : $VM_NAME
- VM Public IP   : $VM_PUBLIC_IP
- SSH            : ssh $ADMIN_USER@$VM_PUBLIC_IP
- MQTT TLS       : mqtts://$VM_PUBLIC_IP:8883
- MQTT user/pass : $MQTT_USER / $MQTT_PASSWORD
- Storage        : $STORAGE_ACCOUNT (container: $ARCHIVE_CONTAINER)
- Function App   : https://$FUNC_HOST
- IoT Hub        : $( [ "$CREATE_IOTHUB" = true ] && echo "$IOTHUB_NAME" || echo "not-created" )

Next:
1) Uji koneksi MQTT TLS dari client device.
2) Deploy code Azure Functions ke app: $FUNC_APP_NAME.
3) Restrict rule SSH NSG ke CIDR statis admin (saat ini: $ADMIN_CIDR).
OUT
