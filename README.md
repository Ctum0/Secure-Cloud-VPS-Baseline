# Secure & Self-Hosted Cloud Infrastructure

A hardened Ubuntu VPS configured as a secure, containerized foundation for future Agentic AI and Detection Engineering projects. This repository documents the "Stage 0" security baseline and the "Stage 1" management infrastructure: a reverse-proxied Docker stack fronted by automatic TLS, with strict firewall and OS hardening already in place.

## Architecture & Tech Stack

```
[ Internet ] → [ UFW Firewall ] → [ Caddy (Auto HTTPS) ] → [ Docker Engine ] → [ Management Stack ]
```

| Layer | Tools |
|-------|-------|
| OS | Ubuntu |
| Firewall | UFW |
| Intrusion Prevention | Fail2ban |
| Container Orchestration | Docker Compose |
| Reverse Proxy / TLS | Caddy (Let's Encrypt auto-HTTPS) |
| Management Stack | Portainer, Homarr, Dashdot |

## Security & Hardening (The "Stage 0" features)

- **SSH Key-Auth only** — password and root logins disabled in `sshd_config`
- **UFW strict ingress rules** — core services only (SSH 22, HTTP 80, HTTPS 443); everything else is denied by default. Service-specific ports are documented in `docs/ufw-rules.txt`
- **Fail2ban** — protects SSH against brute-force attacks with automatic bans
- **Unattended-upgrades** — automatic installation of security patches
- **Automated volume & app-data backups** — daily Docker volume backups with a 7-day retention policy

## Infrastructure & Routing (The "Stage 1" features)

- **Caddy reverse proxy** mapped to a real domain (`yourdomain.com`)
- **Automatic TLS/SSL** via Let's Encrypt (zero-config HTTPS, automatic renewal)
- **Docker Compose orchestration** for the management stack
- **Docker bridge networking** with only required ports published to the host

> Note: Caddy is installed on the host and proxies to published host ports
> (`localhost:9000/7575/3001`); the containers share the default Docker bridge.
> The `proxy` network shown in `architecture-diagram.png` is conceptual.

## Repository Contents

| Folder/File | Contents |
|-------------|----------|
| `config/` | `docker-compose.yml` (Homarr, Dashdot, Portainer) and the `Caddyfile` reverse-proxy configuration |
| `scripts/` | `backup.sh` — Docker volume backup with 7-day retention |
| `docs/` | `deployment-guide.md` (hardening walkthrough), `ufw-rules.txt` (exact firewall rules), `architecture-diagram.png` |

## Usage / Deployment Steps

1. Clone the repository: `git clone https://github.com/yourusername/secure-cloud-infrastructure.git`
2. Copy the environment template into the stack directory and fill in your secrets:
   `cp .env.example config/.env` then `nano config/.env`
3. Generate the Portainer admin password hash (used at first startup) and paste it
   into `PORTAINER_ADMIN_PASSWORD_HASH` in `config/.env`:
   `docker run --rm httpd:2.4-alpine htpasswd -nbB admin <PASSWORD>`
4. Start the management stack:
   `cd config && docker compose up -d`
5. Point your domain's A/AAAA records to the server, copy the `Caddyfile` to `/etc/caddy/Caddyfile`, and reload Caddy.
6. Harden the host by following `docs/deployment-guide.md`.

## Future Scaling

This baseline is intentionally ready to support future deployments of:

- **Wazuh** — SIEM / XDR for Detection Engineering
- **n8n** — workflow automation
- **AI Agents** — Agentic AI services on the existing reverse-proxy and Docker foundation
