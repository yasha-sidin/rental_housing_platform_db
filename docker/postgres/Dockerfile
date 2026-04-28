FROM postgres:18-alpine

COPY docker/postgres/ensure_tablespaces.sh /usr/local/bin/ensure_tablespaces.sh
COPY docker/postgres/replica_entrypoint.sh /usr/local/bin/replica_entrypoint.sh

RUN chmod +x /usr/local/bin/ensure_tablespaces.sh /usr/local/bin/replica_entrypoint.sh

ENTRYPOINT ["ensure_tablespaces.sh"]
CMD ["postgres"]
