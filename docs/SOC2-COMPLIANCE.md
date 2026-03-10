# SOC 2 Compliance Documentation

## Overview

This Docker image is designed to satisfy SOC 2 Type II trust service criteria for Security, Availability, and Confidentiality. This document maps container controls to specific SOC 2 criteria and provides evidence guidance for auditors.

---

## Control Mapping

### CC6.1 — Logical Access Controls

**Requirement:** The entity implements logical access security measures to protect against unauthorized access.

**Controls Implemented:**

| Control | Implementation | Evidence |
|---------|---------------|----------|
| Principle of Least Privilege | Container processes run under `www-data` (non-root) for Nginx and PHP-FPM | `supervisord.conf`, `nginx.conf` user directive |
| Path Restriction | Sensitive paths blocked: `.env`, `.git`, `/vendor`, `/config`, `/tmp` | `default-ssl.conf` location blocks |
| File Extension Blocking | `.sql`, `.yml`, `.ini`, `.zip`, `.sh`, `.log` return 403 | `default-ssl.conf` location blocks |
| No Development Tools | `php8.2-dev`, `php8.2-pcov`, `xdebug` excluded from image | `Dockerfile`, validated by `just test-php` |
| No Privilege Escalation | `gosu` and `sudo` not installed | `Dockerfile` |

### CC6.6 — System Boundary Protection

**Requirement:** The entity implements controls to restrict access at system boundaries.

**Controls Implemented:**

| Control | Implementation | Evidence |
|---------|---------------|----------|
| Web Application Firewall | ModSecurity 3 with OWASP Core Rule Set 4.4.0 | `Dockerfile` lines 62-77, `/etc/nginx/modsec/` |
| SQL Injection Protection | OWASP CRS rules block common injection patterns | Validated by `just test-waf` |
| XSS Protection | OWASP CRS rules + `X-XSS-Protection` header | `default-ssl.conf` |
| CSRF Detection | OWASP CRS anomaly scoring | ModSecurity audit log |
| Request Validation | ModSecurity inspects all inbound requests | `modsecurity.conf` SecRuleEngine On |

### CC6.7 — Encryption in Transit

**Requirement:** The entity uses encryption to protect data in transit.

**Controls Implemented:**

| Control | Implementation | Evidence |
|---------|---------------|----------|
| TLS 1.2+ Only | TLS 1.0 and 1.1 disabled | `nginx.conf` ssl_protocols directive |
| Strong Cipher Suite | ECDHE/DHE with AES-GCM only, no weak ciphers | `nginx.conf` ssl_ciphers directive |
| HSTS Enabled | `Strict-Transport-Security: max-age=31536000` | `default-ssl.conf` |
| HTTP to HTTPS Redirect | All HTTP traffic (except health check) redirects to HTTPS | `default.conf` 301 redirect |
| Validated by | `just test-ssl`, `just test-https-redirect` | Test output logs |

### CC7.1 — Monitoring and Detection

**Requirement:** The entity monitors system components and detects anomalies.

**Controls Implemented:**

| Control | Implementation | Evidence |
|---------|---------------|----------|
| Access Logging | All requests logged in security + JSON formats | `nginx.conf` log formats |
| WAF Audit Logging | ModSecurity logs all inspected requests | `/var/log/modsec/audit.log` |
| SIEM Integration | Wazuh agent ships logs to central manager | `wazuh/ossec.conf` |
| File Integrity Monitoring | Real-time monitoring of web root, configs, system files | `ossec.conf` syscheck directives |
| Rootkit Detection | Automated scan every 12 hours | `ossec.conf` rootcheck |
| Active Response | Automated IP blocking for repeated attacks | `ossec.conf` active-response |
| Container Health Check | Docker HEALTHCHECK polls `/elb-status` every 30s | `Dockerfile` HEALTHCHECK |
| Process Monitoring | Supervisord auto-restarts failed services | `supervisord.conf` |

### CC7.2 — Incident Response

**Requirement:** The entity has procedures to identify and respond to security incidents.

**Controls Implemented:**

| Control | Implementation | Evidence |
|---------|---------------|----------|
| Structured Logging | JSON log format includes IP, method, URI, status, SSL info, user agent | `nginx.conf` json_security format |
| Forensic Data | Request time, body size, cookies, auth headers logged | `nginx.conf` security format |
| Correlation Support | ISO 8601 timestamps, connection IDs in JSON logs | JSON log fields |
| SIEM Ingestion | JSON logs ready for Wazuh/ELK/Splunk/Datadog | `/var/log/nginx/access.json.log` |
| WAF Evidence | ModSecurity audit log captures blocked requests with rule IDs | `/var/log/modsec/audit.log` |

### CC8.1 — Change Management

**Requirement:** The entity authorizes, designs, develops, configures, documents, tests, approves, and implements changes.

**Controls Implemented:**

| Control | Implementation | Evidence |
|---------|---------------|----------|
| Automated Testing | 10+ security tests in justfile | `just test-all` output |
| Build Reproducibility | Pinned versions for OWASP CRS, Wazuh, Node.js | `Dockerfile` ARG directives |
| No Manual Changes | Immutable Docker image, configs baked in at build | Dockerfile, COPY directives |
| File Integrity Monitoring | Wazuh detects unauthorized runtime changes | `ossec.conf` syscheck |
| Test Evidence | Test results can be captured in CI/CD pipeline logs | `just test` output |

---

## Security Headers

All HTTPS responses include the following headers:

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Frame-Options` | `SAMEORIGIN` | Prevents clickjacking |
| `X-Content-Type-Options` | `nosniff` | Prevents MIME-type sniffing |
| `X-XSS-Protection` | `1; mode=block` | Browser XSS filter |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Controls referer leakage |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | Forces HTTPS for 1 year |
| `server_tokens` | `off` | Hides Nginx version |

---

## File Integrity Monitoring Scope

The Wazuh agent monitors the following paths in real-time:

| Path | What It Protects | Report Changes |
|------|-----------------|----------------|
| `/var/www/html` | Application code | Yes |
| `/etc/nginx` | Web server configuration | Yes |
| `/etc/php` | PHP configuration | Yes |
| `/etc/cron.d` | Scheduled tasks | Yes |
| `/etc/nginx/modsec` | WAF rules | No (binary) |
| `/etc/passwd` | User accounts | Yes |
| `/etc/shadow` | Password hashes | Yes |
| `/etc/group` | Group memberships | Yes |

**Scan Frequency:** Every 3600 seconds (1 hour) + real-time inotify

**Excluded:** Log files, swap files, storage/cache directories

---

## Log Retention and Formats

### Access Log Fields (JSON format)

```json
{
  "time": "2026-03-10T19:41:22+00:00",
  "remote_addr": "192.168.1.100",
  "remote_user": "",
  "request": "GET /api/users HTTP/1.1",
  "request_method": "GET",
  "request_uri": "/api/users",
  "status": 200,
  "body_bytes_sent": 1234,
  "request_length": 456,
  "request_time": 0.042,
  "upstream_response_time": "0.040",
  "http_referer": "https://app.example.com/",
  "http_user_agent": "Mozilla/5.0...",
  "http_x_forwarded_for": "10.0.0.1",
  "http_host": "api.example.com",
  "server_protocol": "HTTP/1.1",
  "ssl_protocol": "TLSv1.3",
  "ssl_cipher": "TLS_AES_256_GCM_SHA384",
  "connection": 12345,
  "connection_requests": 1
}
```

### Log Locations

| Log | Path | Format | Purpose |
|-----|------|--------|---------|
| Access (human) | `/var/log/nginx/access.log` | security | Human-readable audit trail |
| Access (SIEM) | `/var/log/nginx/access.json.log` | JSON | Machine-parseable for SIEM |
| Error | `/var/log/nginx/error.log` | nginx default | Error tracking |
| WAF Audit | `/var/log/modsec/audit.log` | ModSecurity | WAF decisions and blocked requests |
| PHP-FPM | `/var/log/php-fpm/error.log` | syslog | Application errors |
| Cron | `/var/log/cron.log` | syslog | Scheduled task execution |
| Supervisor | `/var/log/supervisor/supervisord.log` | supervisor | Process management |
| Wazuh | `/var/ossec/logs/ossec.log` | wazuh | Agent activity |

---

## Automated Test Suite

The following tests validate SOC 2 controls on every build:

| Test | SOC 2 Criteria | What It Validates |
|------|---------------|-------------------|
| `test-health` | CC7.1 | Health check endpoint responds |
| `test-https-redirect` | CC6.7 | HTTP redirects to HTTPS |
| `test-security-headers` | CC6.1, CC6.6 | All security headers present |
| `test-ssl` | CC6.7 | TLS 1.2+ enforced |
| `test-waf` | CC6.6 | WAF blocks SQL injection |
| `test-blocked-paths` | CC6.1 | Sensitive files inaccessible |
| `test-php` | CC6.1 | No dev tools in production |
| `test-services` | CC7.1 | All monitoring services running |
| `test-permissions` | CC6.1 | Correct user/group mapping |

**Usage:**
```bash
# Full lifecycle test
just test-all

# Test running container
just test
```

**CI/CD Integration:** Run `just test-all` in your pipeline and retain output as audit evidence.

---

## Auditor Quick Reference

### Evidence Collection Commands

```bash
# Show all security controls are active
just test

# Show container image contents (no dev tools)
docker exec <container> dpkg -l | grep php

# Show TLS configuration
docker exec <container> cat /etc/nginx/nginx.conf | grep ssl_

# Show WAF is enabled
docker exec <container> cat /etc/nginx/sites-enabled/default-ssl | grep modsecurity

# Show file integrity monitoring config
docker exec <container> cat /var/ossec/etc/ossec.conf

# Show access logs are being written
docker exec <container> tail -5 /var/log/nginx/access.json.log

# Show WAF audit logs
docker exec <container> tail -20 /var/log/modsec/audit.log
```

### Version Pinning

| Component | Version | Update Frequency |
|-----------|---------|-----------------|
| Ubuntu | 24.04 LTS | Every 2 years (supported through 2029) |
| PHP | 8.2 | Ondrej PPA, security patches |
| Node.js | 20 LTS | Every 2 years |
| OWASP CRS | 4.4.0 | Pinned, update via `OWASP_CRS_VERSION` build arg |
| Wazuh Agent | 4.9.0 | Pinned, update via `WAZUH_VERSION` build arg |
| ModSecurity | 3.x | Ubuntu package repository |
