# ZeroClaw (minimal Rust gateway)

This folder now contains a minimal Rust implementation so build/deploy flow can run end-to-end.

Available endpoints:
- `GET /` -> service status JSON
- `GET /health` -> `ok`
- `GET /ready` -> `ok`

Quick local run:

```bash
cd src/zeroclaw
# build + run via Docker (image exposes :8080)
./run_local.sh
```

Quick local run without Docker:

```bash
cd src/zeroclaw
cargo run -- gateway --host 0.0.0.0 --port 8080
```

ACI / ACR deploy:
- See `scripts/deploy_aci.sh` for a single-step script that builds to ACR and deploys to Azure Container Instances.

Secrets used by infra:
- ZEROCLAW_MASTER_KEY
- ZEROCLAW_SALT_KEY
- DATABASE_URL (default: `sqlite:///data/zeroclaw.db`)
