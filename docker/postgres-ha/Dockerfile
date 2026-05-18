FROM postgres:18.4-bookworm

ARG PATRONI_VERSION=4.1.3
ARG PGBACKREST_VERSION=2.58.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gettext-base \
        gcc \
        jq \
        libbz2-dev \
        liblz4-dev \
        libpq-dev \
        libssh2-1-dev \
        libssl-dev \
        libxml2-dev \
        libyaml-dev \
        libzstd-dev \
        meson \
        netcat-openbsd \
        ninja-build \
        pkg-config \
        python3 \
        python3-pip \
        python3-venv \
        zlib1g-dev \
    && curl -fsSL "https://github.com/pgbackrest/pgbackrest/archive/release/${PGBACKREST_VERSION}.tar.gz" -o /tmp/pgbackrest.tar.gz \
    && tar -xzf /tmp/pgbackrest.tar.gz -C /tmp \
    && meson setup /tmp/pgbackrest-build "/tmp/pgbackrest-release-${PGBACKREST_VERSION}" \
    && ninja -C /tmp/pgbackrest-build \
    && cp /tmp/pgbackrest-build/src/pgbackrest /usr/local/bin/pgbackrest \
    && chmod +x /usr/local/bin/pgbackrest \
    && python3 -m venv /opt/patroni \
    && /opt/patroni/bin/pip install --no-cache-dir "patroni[etcd3]==${PATRONI_VERSION}" psycopg[binary] \
    && rm -rf /tmp/pgbackrest.tar.gz /tmp/pgbackrest-release-${PGBACKREST_VERSION} /tmp/pgbackrest-build \
    && rm -rf /var/lib/apt/lists/*

COPY docker/postgres-ha/patroni-entrypoint.sh /usr/local/bin/patroni-entrypoint.sh

RUN chmod +x /usr/local/bin/patroni-entrypoint.sh \
    && mkdir -p /etc/patroni /etc/pgbackrest /var/log/pgbackrest /var/spool/pgbackrest \
    && chown -R postgres:postgres /etc/patroni /etc/pgbackrest /var/log/pgbackrest /var/spool/pgbackrest

ENTRYPOINT ["patroni-entrypoint.sh"]
CMD ["/etc/patroni/patroni.yml.tpl"]
