FROM golang:1.25-alpine AS cli-builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY cmd ./cmd
COPY internal ./internal

RUN go build -o /out/rentalctl ./cmd/rentalctl

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

COPY --from=cli-builder /out/rentalctl /usr/local/bin/rentalctl

CMD ["rentalctl", "--help"]
