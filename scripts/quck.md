git clone https://github.com/theonlyhennygod/zeroclaw.git
cd zeroclaw
cargo build --release
cargo install --path . --force

# Quick setup (no prompts)
zeroclaw onboard --api-key sk-... --provider openrouter

# Or interactive wizard
zeroclaw onboard --interactive

# Or quickly repair channels/allowlists only
zeroclaw onboard --channels-only

# Chat
zeroclaw agent -m "Hello, ZeroClaw!"

# Interactive mode
zeroclaw agent

# Start the gateway (webhook server)
zeroclaw gateway                # default: 127.0.0.1:8080
zeroclaw gateway --port 0       # random port (security hardened)

# Start full autonomous runtime
zeroclaw daemon

# Check status
zeroclaw status

# Run system diagnostics
zeroclaw doctor

# Check channel health
zeroclaw channel doctor

# Get integration setup details
zeroclaw integrations info Telegram

# Manage background service
zeroclaw service install
zeroclaw service status

# Migrate memory from OpenClaw (safe preview first)
zeroclaw migrate openclaw --dry-run
zeroclaw migrate openclaw