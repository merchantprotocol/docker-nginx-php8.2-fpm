FROM ubuntu:24.04

LABEL maintainer="Jonathon Byrdziak"

ARG NODE_VERSION=20
ARG USER_ID=1000
ARG GROUP_ID=1000 

WORKDIR /var/www/html
USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

## Remap www-data to match host UID/GID for volume mount permissions
# Ubuntu 24.04 ships with 'ubuntu' user at 1000:1000 and 'www-data' at 33:33.
# We need www-data at the target UID/GID so mounted files have correct ownership
# on both the host and inside the container.
RUN userdel -f ubuntu 2>/dev/null; \
    groupdel ubuntu 2>/dev/null; \
    userdel -f www-data 2>/dev/null; \
    groupdel www-data 2>/dev/null; \
    groupdel dialout 2>/dev/null; \
    groupadd --gid ${GROUP_ID} www-data && \
    useradd -l -u ${USER_ID} -g www-data -d /home/www-data -s /bin/bash www-data && \
    install -d -m 0755 -o www-data -g www-data /home/www-data

RUN apt-get update \
    && apt-get install lsb-release ca-certificates apt-transport-https software-properties-common -y \
    && add-apt-repository ppa:ondrej/php \
    && apt-get install -y gnupg curl zip unzip git supervisor sqlite3 libcap2-bin libpng-dev python3


RUN apt-get update \
    && apt-get install -y php8.2-cli \
       php8.2-pgsql php8.2-sqlite3 php8.2-odbc php8.2-gd \
       php8.2-curl php8.2-memcached \
       php8.2-imap php8.2-mysql php8.2-mbstring \
       php8.2-xml php8.2-zip php8.2-bcmath php8.2-soap \
       php8.2-intl php8.2-readline \
       php8.2-msgpack php8.2-igbinary php8.2-ldap \
       php8.2-redis \
       php8.2-fpm \
    && php -r "readfile('https://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer \
    && curl -sL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn \
    && apt-get install -y mysql-client \
    && apt-get install -y postgresql-client \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && apt-get update -y \
    && apt-get install nginx -y

# ModSecurity 3 WAF + OWASP Core Rule Set (SOC 2 compliance)
ARG OWASP_CRS_VERSION=4.4.0
RUN apt-get update \
   && apt-get install -y libmodsecurity3 libmodsecurity-dev libnginx-mod-http-modsecurity wget \
   && mkdir -p /etc/nginx/modsec /var/log/modsec \
   && find / -name "modsecurity.conf-recommended" -o -name "modsecurity.conf" 2>/dev/null | head -1 | xargs -I {} cp {} /etc/nginx/modsec/modsecurity.conf \
   && if [ ! -f /etc/nginx/modsec/modsecurity.conf ]; then \
      wget -qO /etc/nginx/modsec/modsecurity.conf https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/modsecurity.conf-recommended; \
   fi \
   && sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf \
   && sed -i 's|SecAuditLog /var/log/modsec_audit.log|SecAuditLog /var/log/modsec/audit.log|' /etc/nginx/modsec/modsecurity.conf \
   && find / -name "unicode.mapping" 2>/dev/null | head -1 | xargs -I {} cp {} /etc/nginx/modsec/unicode.mapping \
   && if [ ! -f /etc/nginx/modsec/unicode.mapping ]; then \
      wget -qO /etc/nginx/modsec/unicode.mapping https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/unicode.mapping; \
   fi \
   && wget -qO /tmp/crs.tar.gz https://github.com/coreruleset/coreruleset/archive/refs/tags/v${OWASP_CRS_VERSION}.tar.gz \
   && tar -xzf /tmp/crs.tar.gz -C /etc/nginx/modsec/ \
   && mv /etc/nginx/modsec/coreruleset-${OWASP_CRS_VERSION} /etc/nginx/modsec/crs \
   && cp /etc/nginx/modsec/crs/crs-setup.conf.example /etc/nginx/modsec/crs/crs-setup.conf \
   && rm /tmp/crs.tar.gz

# ModSecurity main include file
RUN printf '%s\n' \
   'Include /etc/nginx/modsec/modsecurity.conf' \
   'Include /etc/nginx/modsec/crs/crs-setup.conf' \
   'Include /etc/nginx/modsec/crs/rules/*.conf' \
   > /etc/nginx/modsec/main.conf

# Wazuh Agent for SOC 2 SIEM reporting
ARG WAZUH_VERSION=4.9.0
ARG WAZUH_MANAGER=wazuh-manager
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg \
   && echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list \
   && apt-get update \
   && WAZUH_MANAGER=${WAZUH_MANAGER} apt-get install -y wazuh-agent=${WAZUH_VERSION}-* \
   && mkdir -p /var/log/php-fpm

# Wazuh agent config: monitor nginx, modsecurity, php-fpm, and cron logs
COPY wazuh/ossec.conf /var/ossec/etc/ossec.conf

# A couple tools for us
RUN apt-get update \
   && apt-get install -y nano pipx \
   && pipx install ngxtop \
   && pipx ensurepath

RUN setcap "cap_net_bind_service=+ep" /usr/bin/php8.2
RUN mkdir /opt/scripts/

COPY start-container /usr/local/bin/start-container
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY nginx/make-localhost-cert /opt/scripts/make-localhost-cert
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/sites-enabled/default.conf /etc/nginx/sites-available/default
COPY nginx/sites-enabled/default-ssl.conf /etc/nginx/sites-enabled/default-ssl

COPY php/php-fpm.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY php/php.ini /etc/php/8.2/cli/php.ini
COPY php/php.ini /etc/php/8.2/fpm/php.ini
COPY php/opcache.ini /etc/php/8.2/mods-available/opcache.ini
RUN mkdir -p /var/run/php

RUN rm -f /var/www/html/index.nginx-debian.html
RUN mkdir /var/www/html/nginx.d/ 
COPY html/* /var/www/html/

# Installing the cron
RUN apt-get update -y && apt-get install cron -yqq

RUN rm -Rf /etc/cron.daily
RUN rm -Rf /etc/cron.weekly
RUN rm -Rf /etc/cron.monthly
RUN rm -Rf /etc/cron.hourly

COPY cron/samplecron.sh /var/www/html/cron.d/samplecron.sh
COPY cron/runcron.sh /opt/scripts/runcron.sh
COPY cron/crontab /etc/cron.d/webapp

RUN crontab /etc/cron.d/webapp
RUN touch /var/log/cron.log
RUN mkdir /var/log/cron/
RUN chmod 0600 /etc/cron.d/webapp

RUN chmod +x /usr/local/bin/start-container

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -sf http://localhost/elb-status || exit 1

EXPOSE 80
EXPOSE 443

ENTRYPOINT ["start-container"]