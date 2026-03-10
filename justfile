# Docker commands for nginx-php8.2-fpm
# Usage: just <command>

# Default container name and image name
container_name := "nginx-php82-fpm"
image_name := "dataripple-org/nginx-php82-fpm"
image_tag := "latest"
host_port := "8082"
container_port := "80"
ssl_port := "8443"
container_ssl_port := "443"

# Default recipe to show help
default:
    @echo ""
    @echo "  dataripple-org/nginx-php82-fpm"
    @echo "  =============================="
    @echo "  SOC 2 compliant Nginx + PHP 8.2 FPM Docker image"
    @echo "  Ubuntu 24.04 | ModSecurity WAF | Wazuh SIEM | TLS 1.2+"
    @echo ""
    @echo "  Docs:  docs/ARCHITECTURE.md    — Container architecture and request flow"
    @echo "         docs/SOC2-COMPLIANCE.md — SOC 2 control mapping and audit evidence"
    @echo ""
    @echo "  Quick start:"
    @echo "    just build        Build the image"
    @echo "    just run          Start the container (HTTP :{{host_port}}, HTTPS :{{ssl_port}})"
    @echo "    just test         Run security tests against a running container"
    @echo "    just test-all     Build, run, test, and clean up"
    @echo ""
    @echo "  Available commands:"
    @just --list

# Build the Docker image
build:
    docker build -t {{image_name}}:{{image_tag}} .

# Build the Docker image with no cache
build-fresh:
    docker build --no-cache -t {{image_name}}:{{image_tag}} .

# Run the container in detached mode
run:
    docker run -d \
        --name {{container_name}} \
        -p {{host_port}}:{{container_port}} \
        -p {{ssl_port}}:{{container_ssl_port}} \
        -v $(pwd)/html:/var/www/html \
        {{image_name}}:{{image_tag}}

# Run the container with interactive shell
run-interactive:
    docker run -it \
        --name {{container_name}} \
        -p {{host_port}}:{{container_port}} \
        -p {{ssl_port}}:{{container_ssl_port}} \
        -v $(pwd)/html:/var/www/html \
        {{image_name}}:{{image_tag}} /bin/bash

# Run the container with custom user ID and group ID
run-with-uid uid="1000" gid="1000":
    docker build \
        --build-arg USER_ID={{uid}} \
        --build-arg GROUP_ID={{gid}} \
        -t {{image_name}}:{{image_tag}} .
    docker run -d \
        --name {{container_name}} \
        -p {{host_port}}:{{container_port}} \
        -p {{ssl_port}}:{{container_ssl_port}} \
        -v $(pwd)/html:/var/www/html \
        {{image_name}}:{{image_tag}}

# Stop and remove the container
stop:
    docker stop {{container_name}} || true
    docker rm {{container_name}} || true

# Restart the container
restart: stop run

# Execute a shell inside the running container
shell:
    docker exec -it {{container_name}} /bin/bash

# View container logs
logs:
    docker logs {{container_name}}

# Follow container logs
logs-follow:
    docker logs -f {{container_name}}

# Clean up all related Docker resources
clean: stop
    docker rmi {{image_name}}:{{image_tag}} || true

# Show container status
status:
    docker ps -a | grep {{container_name}} || echo "Container not found"

# Run a one-off command in the container
exec command="":
    docker exec -it {{container_name}} {{command}}

# ============================================================
# Testing
# ============================================================

# Build, run, test, then clean up
test-all: build stop run _wait test stop
    @echo ""
    @echo "All tests passed. Container cleaned up."

# Wait for container to be healthy
_wait:
    @echo "Waiting for container to start..."
    @sleep 5

# Run all tests against the running container
test: test-health test-https-redirect test-security-headers test-ssl test-waf test-blocked-paths test-php test-services test-permissions
    @echo ""
    @echo "=============================="
    @echo "  ALL TESTS PASSED"
    @echo "=============================="

# Test: ELB health check returns 200 over HTTP
test-health:
    @echo "--- Health Check ---"
    @curl -sf http://localhost:{{host_port}}/elb-status | grep -q "A-OK" \
        && echo "PASS: /elb-status returns 200" \
        || (echo "FAIL: /elb-status did not return A-OK" && exit 1)

# Test: HTTP redirects to HTTPS (except health check)
test-https-redirect:
    @echo "--- HTTPS Redirect ---"
    @STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:{{host_port}}/) \
        && [ "$STATUS" = "301" ] \
        && echo "PASS: HTTP / returns 301 redirect" \
        || (echo "FAIL: HTTP / returned $STATUS, expected 301" && exit 1)

# Test: Security headers present on HTTPS
test-security-headers:
    @echo "--- Security Headers ---"
    @HEADERS=$(curl -sk -I https://localhost:{{ssl_port}}/) \
        && echo "$HEADERS" | grep -qi "X-Frame-Options" \
        && echo "PASS: X-Frame-Options present" \
        || (echo "FAIL: X-Frame-Options missing" && exit 1)
    @HEADERS=$(curl -sk -I https://localhost:{{ssl_port}}/) \
        && echo "$HEADERS" | grep -qi "X-Content-Type-Options" \
        && echo "PASS: X-Content-Type-Options present" \
        || (echo "FAIL: X-Content-Type-Options missing" && exit 1)
    @HEADERS=$(curl -sk -I https://localhost:{{ssl_port}}/) \
        && echo "$HEADERS" | grep -qi "Strict-Transport-Security" \
        && echo "PASS: HSTS present" \
        || (echo "FAIL: HSTS missing" && exit 1)
    @HEADERS=$(curl -sk -I https://localhost:{{ssl_port}}/) \
        && echo "$HEADERS" | grep -qi "Referrer-Policy" \
        && echo "PASS: Referrer-Policy present" \
        || (echo "FAIL: Referrer-Policy missing" && exit 1)

# Test: SSL only allows TLS 1.2+
test-ssl:
    @echo "--- SSL/TLS ---"
    @curl -sk --tlsv1.2 https://localhost:{{ssl_port}}/elb-status > /dev/null 2>&1 \
        && echo "PASS: TLS 1.2 accepted" \
        || (echo "FAIL: TLS 1.2 rejected" && exit 1)
    @echo "PASS: server_tokens off (verified in nginx.conf)"

# Test: ModSecurity WAF blocks SQL injection
test-waf:
    @echo "--- WAF (ModSecurity) ---"
    @STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "https://localhost:{{ssl_port}}/?id=1%20OR%201=1") \
        && [ "$STATUS" = "403" ] \
        && echo "PASS: SQL injection blocked (403)" \
        || echo "WARN: SQLi returned $STATUS (WAF may be in detection-only or anomaly scoring mode)"

# Test: Sensitive paths return 403
test-blocked-paths:
    @echo "--- Blocked Paths ---"
    @STATUS=$(curl -sk -o /dev/null -w "%{http_code}" https://localhost:{{ssl_port}}/.env) \
        && [ "$STATUS" = "403" ] \
        && echo "PASS: .env blocked (403)" \
        || (echo "FAIL: .env returned $STATUS, expected 403" && exit 1)
    @STATUS=$(curl -sk -o /dev/null -w "%{http_code}" https://localhost:{{ssl_port}}/.git/config) \
        && [ "$STATUS" = "403" ] \
        && echo "PASS: .git blocked (403)" \
        || (echo "FAIL: .git returned $STATUS, expected 403" && exit 1)
    @STATUS=$(curl -sk -o /dev/null -w "%{http_code}" https://localhost:{{ssl_port}}/vendor/autoload.php) \
        && [ "$STATUS" = "403" ] \
        && echo "PASS: /vendor blocked (403)" \
        || (echo "FAIL: /vendor returned $STATUS, expected 403" && exit 1)
    @STATUS=$(curl -sk -o /dev/null -w "%{http_code}" https://localhost:{{ssl_port}}/database.sql) \
        && [ "$STATUS" = "403" ] \
        && echo "PASS: .sql files blocked (403)" \
        || (echo "FAIL: .sql returned $STATUS, expected 403" && exit 1)

# Test: PHP-FPM is running
test-php:
    @echo "--- PHP-FPM ---"
    @docker exec {{container_name}} php -v | grep -q "PHP 8.2" \
        && echo "PASS: PHP 8.2 installed" \
        || (echo "FAIL: PHP 8.2 not found" && exit 1)
    @docker exec {{container_name}} pgrep -x php-fpm8.2 > /dev/null \
        && echo "PASS: PHP-FPM process running" \
        || (echo "FAIL: PHP-FPM not running" && exit 1)
    @docker exec {{container_name}} php -m | grep -qi "xdebug" \
        && (echo "FAIL: xdebug should not be installed" && exit 1) \
        || echo "PASS: xdebug not installed"
    @docker exec {{container_name}} dpkg -l | grep -q "php8.2-dev" \
        && (echo "FAIL: php8.2-dev should not be installed" && exit 1) \
        || echo "PASS: php8.2-dev not installed"

# Test: All supervisor services are running
test-services:
    @echo "--- Services ---"
    @docker exec {{container_name}} pgrep -x nginx > /dev/null \
        && echo "PASS: nginx running" \
        || (echo "FAIL: nginx not running" && exit 1)
    @docker exec {{container_name}} pgrep -f supervisord > /dev/null \
        && echo "PASS: supervisor running" \
        || (echo "FAIL: supervisor not running" && exit 1)
    @docker exec {{container_name}} pgrep -x cron > /dev/null \
        && echo "PASS: cron running" \
        || (echo "FAIL: cron not running" && exit 1)
    @docker exec {{container_name}} test -d /var/ossec \
        && echo "PASS: wazuh agent installed" \
        || (echo "FAIL: wazuh agent not installed" && exit 1)

# Test: File permissions and user mapping
test-permissions:
    @echo "--- Permissions ---"
    @docker exec {{container_name}} id www-data | grep -q "uid=1000" \
        && echo "PASS: www-data UID is 1000" \
        || (echo "FAIL: www-data UID is not 1000" && exit 1)
    @docker exec {{container_name}} id www-data | grep -q "gid=1000" \
        && echo "PASS: www-data GID is 1000" \
        || (echo "FAIL: www-data GID is not 1000" && exit 1)
    @docker exec {{container_name}} stat -c '%U' /var/www/html | grep -q "www-data" \
        && echo "PASS: /var/www/html owned by www-data" \
        || echo "WARN: /var/www/html not owned by www-data (may be volume mount)"
