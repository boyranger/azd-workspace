# SSH Key Login (No Password) for `far-azd`

This guide switches SSH login on your Azure VM from password-based login to SSH key-based login.

Target VM (as of February 16, 2026):
- User: `far-azd`
- Public IP: `20.239.55.227`

If IP changes, check it with:

```bash
az vm show -g zeroclaw-vm-rg-ea -n zeroclaw-b1s -d --query publicIps -o tsv
```

## 1. Generate SSH key on your local machine

If you do not have a key yet:

```bash
ssh-keygen -t ed25519 -C "far-azd@zeroclaw-vm"
```

Default key path:
- Private key: `~/.ssh/id_ed25519`
- Public key: `~/.ssh/id_ed25519.pub`

## 2. Copy key to VM (one last password login)

```bash
ssh-copy-id far-azd@20.239.55.227
```

Enter your current password when prompted.

If `ssh-copy-id` is not installed, use:

```bash
cat ~/.ssh/id_ed25519.pub | ssh far-azd@20.239.55.227 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

## 3. Verify key login works

Open a new terminal and run:

```bash
ssh far-azd@20.239.55.227
```

This should log in without asking for password.

Important:
- Keep this session open until all hardening steps are complete.

## 4. Disable password login on server

Run on VM:

```bash
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

## 5. Final validation

From local machine:

```bash
ssh -o PreferredAuthentications=publickey far-azd@20.239.55.227 "whoami"
```

Expected output:
- `far-azd`

## 6. Optional hardening

Disable root SSH login:

```bash
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

## Recovery (if locked out)

If you accidentally lock yourself out, re-enable password login via Azure RunCommand:

```bash
az vm run-command invoke -g zeroclaw-vm-rg-ea -n zeroclaw-b1s \
  --command-id RunShellScript \
  --scripts "sudo sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && sudo systemctl restart ssh"
```
