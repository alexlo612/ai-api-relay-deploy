## Summary

-

## Verification

- [ ] `docker compose config`
- [ ] `shellcheck scripts/*.sh`
- [ ] Nginx config test
- [ ] Secret/runtime-data scan
- [ ] Documentation updated

## Deployment safety

- [ ] No `.env`, private keys, certificates, dumps, backups, or production logs are committed
- [ ] No destructive volume deletion is part of the change
- [ ] VPS changes, if any, were explicitly requested and recorded
