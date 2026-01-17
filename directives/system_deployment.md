---
priority: high
domain: infrastructure
dependencies: []
conflicts_with: []
last_updated: 2026-01-16
---

# System Deployment (v2.0)

## Goal
Deploy the Flashp application to various environments (Bare Metal, Docker, Coolify, Easypanel) using the automated installation system.

## Success Criteria
- [ ] Installation script completes without errors.
- [ ] Application is accessible via the specified domain or IP.
- [ ] SSL certificate is generated correctly (if domain provided).
- [ ] Deployment state is saved in `/etc/flashp/install.conf`.

## Inputs
- `GIT_URL`: Repository URL.
- `DOMAIN` / `SUBDOMAIN`: Target access domain.
- `ADMIN_EMAIL`: Email for SSL notifications.
- Deployment Method: choice between Bare Metal, Docker, etc.

## Execution Steps
1. Run `execution/flashp_install.sh` with sudo.
2. Follow interactive prompts or provide environment variables if automated.
3. Verify status using the logs in `/var/log/flashp/`.

## Edge Cases
- **DNS Propagation**: Certbot will fail if DNS hasn't propagated. Wait 5-30 mins.
- **Port Conflict**: Script checks for ports 80, 443, 3000.
- **Resource Constraints**: Warns if RAM < 2GB.

## Learnings
- 2026-01-16: Migrated to v2.0 system with automatic rollback and user-level execution for better security.
