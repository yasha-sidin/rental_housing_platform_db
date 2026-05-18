scope: ${PATRONI_SCOPE}
namespace: ${PATRONI_NAMESPACE}
name: ${PATRONI_NAME}

restapi:
  listen: 0.0.0.0:8008
  connect_address: ${PATRONI_REST_CONNECT_ADDRESS}

etcd3:
  hosts: ${ETCD3_HOSTS}

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    synchronous_mode: true
    synchronous_mode_strict: true
    synchronous_node_count: 2
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        archive_mode: "on"
        archive_command: "if [ \"${ENABLE_WAL_ARCHIVE}\" = \"true\" ]; then pgbackrest --stanza=${PGBACKREST_STANZA} archive-push %p; else exit 0; fi"
        archive_timeout: "60s"
        hot_standby: "on"
        max_connections: 200
        max_replication_slots: 20
        max_wal_senders: 20
        shared_preload_libraries: "pg_stat_statements"
        synchronous_commit: "on"
        wal_level: "replica"
  initdb:
    - encoding: UTF8
    - data-checksums
  pg_hba:
    - host all all 0.0.0.0/0 md5
    - host replication ${PATRONI_REPLICATION_USERNAME} 0.0.0.0/0 md5
  users:
    ${PATRONI_REWIND_USERNAME}:
      password: ${PATRONI_REWIND_PASSWORD}
      options:
        - createrole
        - createdb

postgresql:
  listen: 0.0.0.0:5432
  connect_address: ${PATRONI_POSTGRES_CONNECT_ADDRESS}
  data_dir: ${PGDATA}
  bin_dir: /usr/lib/postgresql/18/bin
  authentication:
    superuser:
      username: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
    replication:
      username: ${PATRONI_REPLICATION_USERNAME}
      password: ${PATRONI_REPLICATION_PASSWORD}
    rewind:
      username: ${PATRONI_REWIND_USERNAME}
      password: ${PATRONI_REWIND_PASSWORD}
  parameters:
    unix_socket_directories: /var/run/postgresql

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
