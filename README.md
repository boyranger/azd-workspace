# azd-zeroclaw 🚀

ZeroClaw — minimal Azure template and examples to run a tiny Rust gateway in Azure Container Instances (ACI) or Container Apps. This repo was migrated from LiteLLM to ZeroClaw.

## Recommended (student-friendly): Deploy to Azure Container Instances (ACI) ✅

1) Add Dockerfile (Rust) to `src/zeroclaw/DOCKERFILE` — example below.

2) Build & push to Azure Container Registry (ACR):

```bash
# Login Azure
az login

# Create resource group
az group create --name zeroclaw-rg --location southeastasia

# Create ACR
az acr create --resource-group zeroclaw-rg \
  --name zeroclawacr --sku Basic

# Build and push
az acr build --registry zeroclawacr --image zeroclaw:latest .
```

3) Deploy to ACI (pay-per-second, ultra‑cheap for student credits):

```bash
# Get ACR creds
ACR_PASSWORD=$(az acr credential show --name zeroclawacr --query "passwords[0].value" -o tsv)

# Create container instance
az container create \
  --resource-group zeroclaw-rg \
  --name zeroclaw-gateway \
  --image zeroclawacr.azurecr.io/zeroclaw:latest \
  --cpu 0.5 --memory 0.25 \
  --registry-login-server zeroclawacr.azurecr.io \
  --registry-username zeroclawacr \
  --registry-password $ACR_PASSWORD \
  --dns-name-label zeroclaw-bot \
  --ports 8080 \
  --environment-variables ZEROCLAW_API_KEY="sk-..." ZEROCLAW_PROVIDER="openrouter" \
  --restart-policy Always \
  --location southeastasia
```

4) Get FQDN:

```bash
az container show --resource-group zeroclaw-rg --name zeroclaw-gateway --query ipAddress.fqdn -o tsv
# example: zeroclaw-bot.southeastasia.azurecontainer.io
```

---

## Example Dockerfile (Rust) — use `src/zeroclaw/DOCKERFILE`

```dockerfile
FROM rust:1.75-slim as builder

WORKDIR /build
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/target/release/zeroclaw /usr/local/bin/zeroclaw

WORKDIR /data
VOLUME /data

EXPOSE 8080

ENTRYPOINT ["zeroclaw"]
CMD ["gateway", "--host", "0.0.0.0"]
```

---

## Local development

- Build & run with Docker (repo contains `src/zeroclaw/run_local.sh` and `DOCKERFILE`).
- Use `DATABASE_URL`, `ZEROCLAW_MASTER_KEY` and `ZEROCLAW_SALT_KEY` for local env when required.

## Scripts

- `scripts/deploy_aci.sh` — build → push → deploy to ACI (example use in README)
- `scripts/deploy_azure.sh`, `scripts/check_status.sh`, `scripts/maintenance.sh` — updated to use `zeroclaw` and renamed secrets.

## Infra notes

- Bicep modules were renamed to `zeroclaw` and secure parameter names changed to `zeroclaw_master_key` / `zeroclaw_salt_key`.

---

If you want, I can:
- add CI (GitHub Actions) to build & push to ACR, or
- update the `azd` template to use ACI or Container Apps with `zeroclaw`.

Choose next step. 🔧