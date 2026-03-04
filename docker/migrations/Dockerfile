FROM alpine:3.22

ARG MIGRATE_VERSION=v4.19.0
ARG TARGETARCH=amd64

WORKDIR /app

RUN apk add --no-cache ca-certificates wget

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) ARCH='amd64' ;; \
      arm64) ARCH='arm64' ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    wget -O /tmp/migrate.tar.gz "https://github.com/golang-migrate/migrate/releases/download/${MIGRATE_VERSION}/migrate.linux-${ARCH}.tar.gz"; \
    tar -xzf /tmp/migrate.tar.gz -C /tmp; \
    mv /tmp/migrate /usr/local/bin/migrate; \
    chmod +x /usr/local/bin/migrate; \
    rm -f /tmp/migrate.tar.gz

COPY docker/migrations/prepare_migrations.sh /app/prepare_migrations.sh
COPY docker/migrations/run_migrate.sh /app/run_migrate.sh

RUN chmod +x /app/prepare_migrations.sh /app/run_migrate.sh

CMD ["migrate", "-version"]
