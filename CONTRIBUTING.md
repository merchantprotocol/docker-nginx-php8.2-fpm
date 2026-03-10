# Contributing

This is a SOC 2 compliant production infrastructure image. All changes go through a structured review process to maintain security controls and audit evidence.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [just](https://github.com/casey/just) command runner
- Access to the `dataripple-org` GitHub organization

## Workflow

### 1. Create a Branch

All work happens on feature branches off `main`. Never commit directly to `main`.

```bash
git checkout main
git pull origin main
git checkout -b your-branch-name
```

Use descriptive branch names:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feat/` | New feature | `feat/add-redis-extension` |
| `fix/` | Bug fix | `fix/php-fpm-timeout` |
| `security/` | Security patch or hardening | `security/update-owasp-crs` |
| `docs/` | Documentation only | `docs/update-architecture` |

### 2. Make Your Changes

Before writing code, understand what you're changing:

- Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for container architecture
- Read [docs/SOC2-COMPLIANCE.md](docs/SOC2-COMPLIANCE.md) for security control mapping
- Check which SOC 2 controls your change may affect

### 3. Test Locally

Every change must pass the full test suite before opening a PR.

```bash
# Full lifecycle: build, start, test, clean up
just test-all
```

If you're iterating on a running container:

```bash
just build
just stop
just run
just test
```

The test suite validates:

| Test | What It Checks |
|------|----------------|
| `test-health` | Health check endpoint responds |
| `test-https-redirect` | HTTP redirects to HTTPS |
| `test-security-headers` | All security headers present |
| `test-ssl` | TLS 1.2+ enforced |
| `test-waf` | WAF blocks SQL injection |
| `test-blocked-paths` | Sensitive files return 403 |
| `test-php` | PHP 8.2 running, no dev tools |
| `test-services` | All services running |
| `test-permissions` | UID/GID mapping correct |

### 4. Open a Pull Request

Push your branch and open a PR against `main`:

```bash
git push -u origin your-branch-name
```

Your PR must:

- Pass the CI pipeline (build, security tests, Trivy vulnerability scan)
- Receive at least one approval from a code owner
- Fill out the PR template, including the SOC 2 impact section
- Have no secrets, credentials, or debug code in the diff

### 5. Review and Merge

PRs are squash-merged into `main`. The CI pipeline runs automatically on every push and PR.

## Rules

### Do

- Pin specific versions for any new packages or dependencies
- Add tests for any new security controls
- Update documentation when changing architecture, configs, or security controls
- Keep the image minimal — every added package increases the attack surface

### Don't

- Add development tools (`xdebug`, `php-dev`, `pcov`, etc.)
- Add privilege escalation tools (`sudo`, `gosu`, `su`)
- Disable or weaken WAF rules without a documented justification
- Lower TLS requirements below 1.2
- Remove security headers
- Commit `.env` files, credentials, or secrets
- Use `latest` tags for pinned dependencies — always specify a version

## Security Changes

Changes that affect security controls require extra scrutiny:

| File / Directory | SOC 2 Controls | Review Required |
|------------------|---------------|-----------------|
| `Dockerfile` | CC6.1, CC8.1 | Always |
| `nginx/` | CC6.1, CC6.6, CC6.7 | Always |
| `nginx/sites-enabled/` | CC6.6, CC6.7 | Always |
| `wazuh/` | CC7.1, CC7.2 | Always |
| `supervisord.conf` | CC7.1 | Always |
| `.github/workflows/` | CC8.1 | Always |
| `php/` | CC6.1 | When adding extensions |
| `docs/` | CC8.1 | When controls change |

If your change modifies a SOC 2 control, update [docs/SOC2-COMPLIANCE.md](docs/SOC2-COMPLIANCE.md) to reflect the change.

## Adding PHP Extensions

1. Add the package to the `apt-get install` block in the `Dockerfile`
2. Verify it is not a development-only package
3. Run `just test-all` to confirm the image builds and passes all tests
4. Update the PHP Extensions list in `README.md`

## Updating Pinned Versions

Versions are pinned via `ARG` directives in the `Dockerfile`:

```dockerfile
ARG OWASP_CRS_VERSION=4.4.0
ARG WAZUH_VERSION=4.9.0
ARG NODE_VERSION=20
```

When updating a pinned version:

1. Update the `ARG` in the `Dockerfile`
2. Run `just test-all`
3. Update the version table in [docs/SOC2-COMPLIANCE.md](docs/SOC2-COMPLIANCE.md)
4. Note the version change in your PR description

## Questions

Open a [Feature Request](https://github.com/dataripple-org/docker-nginx-php8.2-fpm/issues/new?template=feature_request.yml) or [Bug Report](https://github.com/dataripple-org/docker-nginx-php8.2-fpm/issues/new?template=bug_report.yml) if you're unsure about something.
