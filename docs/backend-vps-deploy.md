# Deploy Backend VPS (Azure CLI)

Panduan cepat untuk provisioning backend MVP di Azure VPS (VM + Mosquitto + Function App).

## Prasyarat

- Azure CLI (`az`) sudah terpasang.
- Sudah login: `az login`
- Punya SSH public key, default: `~/.ssh/id_ed25519.pub`

## Jalankan deploy

```bash
./scripts/deploy_backend_vps.sh \
  --subscription <SUBSCRIPTION_ID> \
  --rg MYLOWCOSTVM_GROUP \
  --location eastasia \
  --vm-name zeroclaw-b1s \
  --admin-user far-azd \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --admin-cidr <YOUR_PUBLIC_IP>/32 \
  --yes
```

Catatan:
- `--admin-cidr` penting untuk membatasi SSH (contoh: `203.0.113.10/32`).
- Port `8883` (MQTT TLS) dibuka default.
- Port `1883` publik tidak dipakai.
- Untuk production, gunakan cert CA/domain resmi (Let's Encrypt script tersedia).

## Cek status

```bash
./scripts/check_backend_vps_status.sh --rg MYLOWCOSTVM_GROUP
```

## Verifikasi resource aktif (penting)

Jika muncul error `ResourceGroupNotFound`, cek subscription dan resource yang benar:

```bash
az account show --query "{name:name,id:id}" -o table
az group list --query "[].name" -o tsv
az vm list -d --query "[].{rg:resourceGroup,name:name,ip:publicIps,power:powerState}" -o table
```

Current known active backend (20 Februari 2026):
- Resource Group: `MYLOWCOSTVM_GROUP`
- VM: `zeroclaw-b1s`
- Public IP: `20.24.82.139`

## Upgrade TLS ke Let's Encrypt (setelah domain siap)

Prasyarat:
- Domain/FQDN sudah punya `A record` ke IP VM.
- Siapkan email untuk registrasi Let's Encrypt.

Eksekusi:

```bash
./scripts/enable_mqtt_tls_letsencrypt.sh \
  --domain mqtt.roboria.web.id \
  --email you@example.com \
  --rg MyLowCostVM_group \
  --vm zeroclaw-b1s \
  --nsg mqtt-saas-b1s-nsg
```

Catatan:
- Script membuka port `80` sementara untuk ACME challenge, lalu menutupnya otomatis.
- Jika restart mosquitto gagal, script auto-rollback ke cert sebelumnya.

## Hasil deploy

Script menampilkan:
- VM public IP + perintah SSH
- endpoint MQTT TLS
- Function App host
- kredensial MQTT awal

Simpan kredensial MQTT output deploy ke secret manager secepatnya.

## Post-deploy hardening broker (transitional model)

Saat firmware belum tenant-based, gunakan isolasi credential per-device.

1. Hapus ACL global dari `/etc/mosquitto/acl`:
```conf
user admin
topic readwrite #
```

2. Buat user unik per-device:
```bash
sudo mosquitto_passwd /etc/mosquitto/passwd <device-id>
```

3. Tambahkan ACL per-device:
```conf
user <device-id>
topic write devices/<device-id>/#
topic write device/<device-id>/#
```

4. Restart dan validasi broker:
```bash
sudo systemctl restart mosquitto
sudo systemctl is-active mosquitto
```

5. Verifikasi user broker (tanpa hash):
```bash
sudo cut -d: -f1 /etc/mosquitto/passwd
```

Catatan permission file:
- Untuk environment saat ini, gunakan:
```bash
sudo chown root:mosquitto /etc/mosquitto/passwd /etc/mosquitto/acl
sudo chmod 640 /etc/mosquitto/passwd /etc/mosquitto/acl
```
