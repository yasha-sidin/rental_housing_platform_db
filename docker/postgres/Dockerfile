FROM postgres:18-alpine

COPY docker/postgres/ensure_tablespaces.sh /usr/local/bin/ensure_tablespaces.sh

RUN chmod +x /usr/local/bin/ensure_tablespaces.sh

ENTRYPOINT ["ensure_tablespaces.sh"]
CMD ["postgres"]
