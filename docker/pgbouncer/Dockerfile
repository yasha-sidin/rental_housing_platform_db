FROM alpine:3.22

ARG PGBOUNCER_VERSION=1.25.2

RUN apk add --no-cache --virtual .build-deps \
        autoconf \
        automake \
        build-base \
        c-ares-dev \
        curl \
        libevent-dev \
        libtool \
        openssl-dev \
        pandoc \
        pkgconf \
    && apk add --no-cache c-ares libevent openssl \
    && curl -fsSL "https://www.pgbouncer.org/downloads/files/${PGBOUNCER_VERSION}/pgbouncer-${PGBOUNCER_VERSION}.tar.gz" -o /tmp/pgbouncer.tar.gz \
    && tar -xzf /tmp/pgbouncer.tar.gz -C /tmp \
    && cd "/tmp/pgbouncer-${PGBOUNCER_VERSION}" \
    && ./configure --prefix=/usr --with-cares \
    && make -j"$(nproc)" \
    && make install \
    && addgroup -S pgbouncer \
    && adduser -S -G pgbouncer pgbouncer \
    && rm -rf /tmp/pgbouncer.tar.gz "/tmp/pgbouncer-${PGBOUNCER_VERSION}" \
    && apk del .build-deps

COPY docker/pgbouncer/pgbouncer-entrypoint.sh /usr/local/bin/pgbouncer-entrypoint.sh
RUN chmod +x /usr/local/bin/pgbouncer-entrypoint.sh

USER pgbouncer

ENTRYPOINT ["pgbouncer-entrypoint.sh"]
CMD ["pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
