---
priority: medium
domain: infrastructure
dependencies: [system_deployment.md]
conflicts_with: []
last_updated: 2026-01-16
---

# Domain Management

## Goal
Manage domains, Nginx configurations, and SSL certificates for services running on the server (especially Portainer stacks).

## Success Criteria
- [ ] New domain added and resolving correctly via HTTPS.
- [ ] Nginx configuration created in `/etc/nginx/sites-available/`.
- [ ] SSL certificate generated via Let's Encrypt.
- [ ] List of configured domains is up to date.

## Inputs
- Target Domain name.
- Backend Service Port.
- Admin Email for SSL.
- WebSocket usage flag.

## Execution Steps
1. Run `execution/domain-manager.sh` with sudo.
2. Select option (Add, List, Remove, Renew, Purge Nginx/Certbot).
3. Provide details as prompted by the wizard.

## Edge Cases
- **Missing Proxie Pass**: Ensure the container is running on the specified port.
- **DNS Mismatch**: Domain must point to the server IP.

## Learnings
- 2026-01-16: Formally introduced the domain-manager script to separate infrastructure management from application installation.
