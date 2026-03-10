# Architecture Overview

## System Architecture

This Docker image provides a production-grade, SOC 2 compliant web server platform running Nginx with PHP 8.2 FPM, security monitoring, and enterprise logging.

### Container Components

```
+------------------------------------------------------------------+
|  Docker Container (Ubuntu 24.04)                                  |
|                                                                    |
|  +-------------------+    +-------------------+                    |
|  |   Supervisord     |    |   Wazuh Agent     |                    |
|  |   (PID 1)         |    |   (SIEM Client)   |                    |
|  +--------+----------+    +--------+----------+                    |
|           |                         |                              |
|   +-------+-------+                |                              |
|   |       |       |                |                              |
|   v       v       v                v                              |
| Nginx  PHP-FPM  Cron    File Integrity Monitor                   |
| :80    sock     (1min)   Rootkit Detection                       |
| :443                     Log Collection                           |
|   |       |                        |                              |
|   v       v                        v                              |
| ModSecurity WAF          Wazuh Manager (external)                |
| OWASP CRS 4.4.0                                                  |
|                                                                    |
+------------------------------------------------------------------+
```

### Request Flow

```
Client Request
      |
      v
  Port 80 (HTTP)                    Port 443 (HTTPS)
      |                                   |
      v                                   v
  ModSecurity WAF                   ModSecurity WAF
      |                                   |
      v                                   v
  /elb-status? ──YES──> 200 OK      Security Headers Applied
      |                              (HSTS, X-Frame-Options, etc.)
      NO                                  |
      |                                   v
      v                              Static File? ──YES──> Serve + Cache
  301 Redirect ──> HTTPS                  |
                                          NO
                                          |
                                          v
                                     *.php? ──YES──> PHP-FPM (unix socket)
                                          |
                                          NO
                                          |
                                          v
                                     Blocked Path? ──YES──> 403 Forbidden
                                          |
                                          NO
                                          |
                                          v
                                     try_files $uri /index.html
```

### Process Management

Supervisord manages all container processes with defined startup priorities:

| Service     | Priority | Auto-Restart | Max Retries | Purpose                    |
|-------------|----------|--------------|-------------|----------------------------|
| Nginx       | 900      | Yes          | 10          | Web server                 |
| PHP-FPM     | 901      | Yes          | 10          | PHP process manager        |
| Cron        | default  | Yes          | 2           | Scheduled tasks            |
| Wazuh Agent | 100      | Yes          | 5           | Security monitoring        |

### Logging Architecture

```
Nginx Access ──> /var/log/nginx/access.log (security format)
             ──> /var/log/nginx/access.json.log (JSON for SIEM)
Nginx Errors ──> /var/log/nginx/error.log
PHP-FPM      ──> /var/log/php-fpm/error.log
ModSecurity  ──> /var/log/modsec/audit.log
Cron         ──> /var/log/cron.log
Supervisor   ──> /var/log/supervisor/supervisord.log
                        |
                        v
                  Wazuh Agent ──> Wazuh Manager ──> SIEM Dashboard
```

### Volume Mount Strategy

```
Host Machine                    Container
/your/app/code  ──mount──>  /var/www/html/
                                |
                                +── nginx.d/        (config overrides)
                                +── supervisor.d/    (extra services)
                                +── docker.d/        (startup scripts)
                                +── cron.d/          (cron jobs)
                                +── .env             (environment vars)
```

The container remaps `www-data` to UID/GID 1000 so file ownership matches between the host and container on mounted volumes.

### Configuration Injection

Applications can override defaults at runtime by placing files in `/var/www/html/nginx.d/`:

| File in nginx.d/    | Overrides                                   |
|---------------------|---------------------------------------------|
| `php-fpm.conf`      | `/etc/php/8.2/fpm/pool.d/www.conf`          |
| `nginx.conf`        | `/etc/nginx/sites-available/default`         |
| `nginx-ssl.conf`    | `/etc/nginx/sites-enabled/default-ssl`       |
| `php.ini`           | Both FPM and CLI php.ini                     |

### Network Ports

| Port | Protocol | Purpose                                      |
|------|----------|----------------------------------------------|
| 80   | HTTP     | Health check + HTTPS redirect                |
| 443  | HTTPS    | Application traffic (TLS 1.2+ only)          |
| 1514 | TCP      | Wazuh agent to manager (outbound)            |
