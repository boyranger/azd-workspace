# Deploy Backend VPS (Azure CLI)

Panduan cepat untuk provisioning backend MVP di Azure VPS (VM + Mosquitto + Function App + Blob).

## Prasyarat

- Azure CLI (`az`) sudah terpasang.
- Sudah login: `az login`
- Punya SSH public key, default: `~/.ssh/id_ed25519.pub`

## Jalankan deploy

```bash
./scripts/deploy_backend_vps.sh \
  --subscription <SUBSCRIPTION_ID> \
  --rg zeroclaw-vm-rg-ea \
  --location eastasia \
  --vm-name zeroclaw-b1s \
  --admin-user far-azd \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --admin-cidr <YOUR_PUBLIC_IP>/32 \
  --create-iothub \
  --yes
```

Catatan:
- `--admin-cidr` penting untuk membatasi SSH (contoh: `203.0.113.10/32`).
- Port `8883` (MQTT TLS) dibuka default.
- Port `1883` plain MQTT hanya dibuka jika pakai `--enable-plain-mqtt`.
- Port `9001` MQTT WebSocket hanya dibuka jika pakai `--enable-websocket`.
- Bootstrap VM membuat sertifikat TLS self-signed (`mosquitto`). Untuk production, ganti dengan cert CA/domain resmi.

## Cek status

```bash
./scripts/check_backend_vps_status.sh --rg zeroclaw-vm-rg-ea
```

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
  --nsg zeroclaw-b1s-nsg
```

Catatan:
- Script membuka port `80` sementara untuk ACME challenge, lalu menutupnya otomatis.
- Jika restart mosquitto gagal, script auto-rollback ke cert sebelumnya.

## Hasil deploy

Script menampilkan:
- VM public IP + perintah SSH
- endpoint MQTT TLS
- Function App host
- Storage account + blob container archive
- kredensial MQTT awal

Simpan kredensial MQTT output deploy ke secret manager secepatnya.
