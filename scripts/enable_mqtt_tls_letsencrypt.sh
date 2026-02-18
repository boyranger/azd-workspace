#!/usr/bin/env bash
set -euo pipefail

# Enable Let's Encrypt TLS for Mosquitto with safety rollback.
# Usage:
#   ./scripts/enable_mqtt_tls_letsencrypt.sh \
#     --domain mqtt.example.com \
#     --email you@example.com \
#     --rg MyLowCostVM_group \
#     --vm zeroclaw-b1s \
#     --nsg zeroclaw-b1s-nsg

DOMAIN=""
EMAIL=""
RG="MyLowCostVM_group"
VM="zeroclaw-b1s"
NSG="zeroclaw-b1s-nsg"
HTTP_RULE_NAME="allow-http-certbot"
HTTP_RULE_PRIORITY="1015"

usage() {
  sed -n '1,80p' "$0"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;
    --rg) RG="$2"; shift 2 ;;
    --vm) VM="$2"; shift 2 ;;
    --nsg) NSG="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

: "${DOMAIN:?--domain is required}"
: "${EMAIL:?--email is required}"

if ! command -v az >/dev/null 2>&1; then
  echo "Error: az CLI not found" >&2
  exit 2
fi

VM_IP=$(az vm show -d -g "$RG" -n "$VM" --query publicIps -o tsv)
if [ -z "$VM_IP" ]; then
  echo "Error: VM public IP not found" >&2
  exit 2
fi

DNS_JSON=$(curl -s "https://dns.google/resolve?name=${DOMAIN}&type=A")
DNS_IPS=$(echo "$DNS_JSON" | jq -r '.Answer[]?.data // empty')
if [ -z "$DNS_IPS" ]; then
  echo "Error: Domain ${DOMAIN} has no A record yet." >&2
  echo "$DNS_JSON" | jq .
  exit 3
fi

if ! echo "$DNS_IPS" | grep -Fxq "$VM_IP"; then
  echo "Error: Domain ${DOMAIN} does not point to VM IP ${VM_IP}." >&2
  echo "A records:" >&2
  echo "$DNS_IPS" >&2
  exit 3
fi

cleanup() {
  az network nsg rule delete -g "$RG" --nsg-name "$NSG" -n "$HTTP_RULE_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "[1/4] Open temporary HTTP 80 for ACME challenge"
az network nsg rule create \
  -g "$RG" \
  --nsg-name "$NSG" \
  -n "$HTTP_RULE_NAME" \
  --priority "$HTTP_RULE_PRIORITY" \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes '*' \
  --destination-port-ranges 80 >/dev/null

echo "[2/4] Issue cert + install with rollback logic on VM"
az vm run-command invoke -g "$RG" -n "$VM" --command-id RunShellScript --scripts "
set -euo pipefail
DOMAIN='${DOMAIN}'
EMAIL='${EMAIL}'
TS=\$(date +%Y%m%d%H%M%S)
BACKUP_DIR=/etc/mosquitto/certs/backup-\$TS
mkdir -p \"\$BACKUP_DIR\"

cp -a /etc/mosquitto/certs/server.crt \"\$BACKUP_DIR\"/server.crt.bak || true
cp -a /etc/mosquitto/certs/server.key \"\$BACKUP_DIR\"/server.key.bak || true

apt-get update -y >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y certbot >/dev/null

certbot certonly --standalone --non-interactive --agree-tos --keep-until-expiring -m \"\$EMAIL\" -d \"\$DOMAIN\"

cp /etc/letsencrypt/live/\$DOMAIN/fullchain.pem /etc/mosquitto/certs/server.crt
cp /etc/letsencrypt/live/\$DOMAIN/privkey.pem /etc/mosquitto/certs/server.key
chown root:mosquitto /etc/mosquitto/certs/server.crt /etc/mosquitto/certs/server.key
chmod 640 /etc/mosquitto/certs/server.crt /etc/mosquitto/certs/server.key

if ! systemctl restart mosquitto; then
  echo 'Mosquitto restart failed, rolling back certs...'
  cp \"\$BACKUP_DIR\"/server.crt.bak /etc/mosquitto/certs/server.crt || true
  cp \"\$BACKUP_DIR\"/server.key.bak /etc/mosquitto/certs/server.key || true
  systemctl restart mosquitto
  exit 1
fi

systemctl is-active mosquitto

mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat >/etc/letsencrypt/renewal-hooks/deploy/mosquitto-reload.sh <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
DOMAIN=\"${DOMAIN}\"
cp /etc/letsencrypt/live/\$DOMAIN/fullchain.pem /etc/mosquitto/certs/server.crt
cp /etc/letsencrypt/live/\$DOMAIN/privkey.pem /etc/mosquitto/certs/server.key
chown root:mosquitto /etc/mosquitto/certs/server.crt /etc/mosquitto/certs/server.key
chmod 640 /etc/mosquitto/certs/server.crt /etc/mosquitto/certs/server.key
systemctl restart mosquitto
HOOK
chmod +x /etc/letsencrypt/renewal-hooks/deploy/mosquitto-reload.sh

echo 'TLS cert installed successfully'
" >/dev/null

echo "[3/4] Verify external TLS certificate subject"
timeout 15 openssl s_client -connect "${VM_IP}:8883" -servername "${DOMAIN}" -showcerts </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer

echo "[4/4] Done. Temporary HTTP rule will be removed automatically."
