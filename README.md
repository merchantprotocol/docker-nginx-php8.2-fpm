# Nginx + PHP 8.2 FPM

A production-grade, SOC 2 compliant Docker image for PHP web applications. Built on Ubuntu 24.04 with Nginx, PHP 8.2 FPM, ModSecurity WAF, and Wazuh SIEM integration.

## Features

| Category | Details |
|----------|---------|
| **Web Server** | Nginx with PHP 8.2 FPM over Unix socket |
| **WAF** | ModSecurity 3 + OWASP Core Rule Set 4.4.0 |
| **TLS** | TLS 1.2+ only, AEAD cipher suites, HSTS |
| **Security Headers** | X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Referrer-Policy |
| **SIEM** | Wazuh agent with file integrity monitoring and rootkit detection |
| **Logging** | Dual-format access logs (human-readable + JSON for SIEM ingestion) |
| **Health Check** | Built-in `/elb-status` endpoint for AWS ELB/ALB |
| **Process Manager** | Supervisord with auto-restart for all services |

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [just](https://github.com/casey/just) (command runner)

### Build and Run

```bash
# Build the image
just build

# Start the container
just run

# Run the full test suite
just test
```

The container exposes:
- **HTTP** on port `8082` (health check + HTTPS redirect)
- **HTTPS** on port `8443` (application traffic)

### Docker Compose

```yaml
services:
  app:
    image: dataripple-org/nginx-php82-fpm:latest
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "./:/var/www/html:rw"
    environment:
      - WAZUH_MANAGER=your-wazuh-manager
      - WAZUH_REGISTRATION_PASSWORD=your-password
      - WAZUH_AGENT_NAME=your-agent-name
```

## Configuration

Mount your application code to `/var/www/html`. The container supports runtime configuration overrides by placing files in the `nginx.d/` directory within your application root:

| File in `nginx.d/` | Overrides |
|---------------------|-----------|
| `php-fpm.conf` | PHP-FPM pool configuration |
| `nginx.conf` | Default Nginx server block |
| `nginx-ssl.conf` | SSL server block |
| `php.ini` | PHP configuration (FPM + CLI) |

Additional extension points:

| Directory | Purpose |
|-----------|---------|
| `supervisor.d/` | Additional Supervisord program configs |
| `docker.d/` | Shell scripts executed on container startup |
| `cron.d/` | Cron job scripts (`.sh` files) |

## Volume Permissions

The container remaps `www-data` to UID/GID `1000` by default so file ownership matches between host and container on mounted volumes. To use a different UID/GID:

```bash
just run-with-uid 1001 1001
```

Or pass build args directly:

```bash
docker build --build-arg USER_ID=1001 --build-arg GROUP_ID=1001 -t dataripple-org/nginx-php82-fpm .
```

## Security

This image is designed for SOC 2 Type II compliance. Key controls include:

- **Least privilege** -- Nginx and PHP-FPM run as `www-data` (non-root). No `sudo`, `gosu`, or dev tools installed.
- **WAF** -- ModSecurity 3 with OWASP CRS blocks SQL injection, XSS, and other OWASP Top 10 attacks.
- **Path restrictions** -- `.env`, `.git`, `/vendor`, `/config`, `/tmp`, and sensitive file extensions (`.sql`, `.yml`, `.ini`, `.zip`, `.sh`, `.log`) return 403.
- **TLS hardening** -- TLS 1.0/1.1 disabled. Only ECDHE/DHE with AES-GCM ciphers accepted.
- **SIEM integration** -- Wazuh agent ships logs to a central manager with file integrity monitoring, rootkit detection, and active response.
- **Structured logging** -- JSON access logs at `/var/log/nginx/access.json.log` ready for Wazuh, ELK, Splunk, or Datadog.

For the full SOC 2 control mapping, see [docs/SOC2-COMPLIANCE.md](docs/SOC2-COMPLIANCE.md).

## Testing

The included test suite validates all security controls:

```bash
# Full lifecycle: build, start, test, clean up
just test-all

# Test a running container
just test
```

| Test | What It Validates |
|------|-------------------|
| `test-health` | `/elb-status` health check responds |
| `test-https-redirect` | HTTP 301 redirect to HTTPS |
| `test-security-headers` | All security headers present |
| `test-ssl` | TLS 1.2+ enforced |
| `test-waf` | WAF blocks SQL injection |
| `test-blocked-paths` | Sensitive files return 403 |
| `test-php` | PHP 8.2 running, no dev tools |
| `test-services` | Nginx, Supervisor, Cron, Wazuh all running |
| `test-permissions` | Correct UID/GID mapping |

## Included Software

| Component | Version | Notes |
|-----------|---------|-------|
| Ubuntu | 24.04 LTS | Supported through 2029 |
| PHP | 8.2 | Ondrej PPA |
| Node.js | 20 LTS | Via NodeSource |
| Nginx | Latest | Ubuntu package |
| ModSecurity | 3.x | With OWASP CRS 4.4.0 |
| Wazuh Agent | 4.9.0 | SIEM + FIM |
| Composer | Latest | PHP dependency manager |
| Yarn | Latest | Node.js package manager |

### PHP Extensions

bcmath, cli, curl, fpm, gd, igbinary, imap, intl, ldap, mbstring, memcached, msgpack, mysql, odbc, pgsql, readline, redis, soap, sqlite3, xml, zip

## Documentation

- [Architecture Overview](docs/ARCHITECTURE.md) -- Container components, request flow, logging architecture, and volume mount strategy
- [SOC 2 Compliance](docs/SOC2-COMPLIANCE.md) -- Control mapping, audit evidence commands, and security header reference

## License

Proprietary software. Copyright Merchant Protocol, LLC. Licensed to Dataripple.
