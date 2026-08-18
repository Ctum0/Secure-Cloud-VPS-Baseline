# Deployment Guide — Secure VPS Hardening (Stage 0)

Step-by-step hardening of a fresh Ubuntu VPS: SSH key authentication, fail2ban,
unattended-upgrades, Docker installation, and a strict UFW firewall.

> Run every command as `root` or via `sudo`. Replace placeholders where noted.

## 1. Update the base system

```bash
sudo apt update && sudo apt upgrade -y
```

## 2. SSH Key-Auth only

Generate a key pair on your **local** machine (not the server):

```bash
ssh-keygen -t ed25519 -C "you@example.com"
```

Copy the public key to the server:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@YOUR_SERVER_IP
```

Confirm key login works, then disable password and root authentication:

```bash
sudo nano /etc/ssh/sshd_config
```

Set:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

Reload the service:

```bash
sudo systemctl reload sshd
```

## 3. Fail2ban — SSH brute-force protection

```bash
sudo apt install fail2ban -y
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

Create `/etc/fail2ban/jail.d/ssh.local`:

```ini
[sshd]
enabled = true
port = 22
maxretry = 5
bantime = 3600
```

Enable and start:

```bash
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
```

## 4. Unattended-upgrades — automatic OS patching

```bash
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

Verify the config:

```bash
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Ensure security updates are enabled (default) and restart:

```bash
sudo systemctl enable --now unattended-upgrades
```

## 5. Install Docker Engine

```bash
sudo apt install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

Add the repository:

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Install:

```bash
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

Add your user to the `docker` group (re-login afterwards):

```bash
sudo usermod -aG docker $USER
```

Verify:

```bash
docker --version
docker compose version
```

## 6. UFW — strict firewall

Set default policies (deny all incoming, allow all outgoing):

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

Allow only the required services:

```bash
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP (Let's Encrypt / Caddy)
sudo ufw allow 443/tcp     # HTTPS
```

Enable and verify:

```bash
sudo ufw enable
sudo ufw status verbose
```

The exact rules for this host are recorded in `ufw-rules.txt`. The production
host also exposes service-specific ports (`2822/tcp`, `60000:61000/udp`) that
are not part of the minimal baseline above.

## 7. Deploy the management stack

```bash
cd /opt
git clone https://github.com/yourusername/secure-cloud-infrastructure.git
cd secure-cloud-infrastructure
cp .env.example config/.env
nano config/.env                    # fill in passwords

# Generate the Portainer admin password hash and paste the output into
# PORTAINER_ADMIN_PASSWORD_HASH in config/.env:
docker run --rm httpd:2.4-alpine htpasswd -nbB admin <PASSWORD>

cd config && docker compose up -d
```

## 8. Configure the reverse proxy (Stage 1)

Install Caddy:

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/deb.deb' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy -y
```

Copy the config and point your domain's A/AAAA records at the server, then reload:

```bash
sudo cp /opt/secure-cloud-infrastructure/config/Caddyfile /etc/caddy/Caddyfile
sudo caddy reload
```

Caddy automatically obtains and renews Let's Encrypt certificates for every
route in the file.

## 9. Backup automation

Add a cron job for the daily volume backup (adjust the volume names to yours):

```bash
crontab -e
```

```cron
0 2 * * * cd /opt/secure-cloud-infrastructure && BACKUP_DIR=/opt/backups ./scripts/backup.sh portainer_data config/homarr/appdata
```
