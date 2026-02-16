# ZeroClaw (placeholder)

This repository has been migrated from LiteLLM to ZeroClaw. Replace the code in `src/zeroclaw` with your real ZeroClaw implementation.

Quick local run:

```bash
cd src/zeroclaw
# build + run via Docker (image exposes :8080)
./run_local.sh
```

ACI / ACR deploy:
- See `scripts/deploy_aci.sh` for a single-step script that builds to ACR and deploys to Azure Container Instances.

Secrets used by infra:
- ZEROCLAW_MASTER_KEY
- ZEROCLAW_SALT_KEY
- DATABASE_URL
