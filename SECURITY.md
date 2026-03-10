# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

### Contact

Email: security@merchantprotocol.com

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested remediation (if any)

### Response Timeline

| Stage | Timeframe |
|-------|-----------|
| Acknowledgment | Within 2 business days |
| Initial assessment | Within 5 business days |
| Resolution target | Within 30 days for critical issues |

### Scope

This policy covers the Docker image and all configuration files in this repository, including:

- Dockerfile and build configuration
- Nginx configuration and WAF rules
- PHP-FPM configuration
- Wazuh SIEM agent configuration
- CI/CD pipeline definitions

### Out of Scope

- Vulnerabilities in upstream packages (Ubuntu, PHP, Nginx) -- report these to the upstream maintainers
- Issues in applications deployed on top of this image

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |

## Security Controls

This image implements controls mapped to SOC 2 Type II trust service criteria. See [docs/SOC2-COMPLIANCE.md](docs/SOC2-COMPLIANCE.md) for the full control mapping.
