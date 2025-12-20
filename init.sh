#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username postgres --dbname postgres <<-EOSQL
    DROP ROLE IF EXISTS replicator;
	CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'my_replicator_password';
    SELECT * FROM pg_create_physical_replication_slot('replication_slot_slave1');
EOSQL


pg_basebackup -D /var/lib/postgresql/data-slave -S replication_slot_slave1 -X stream -P -U replicator -Fp -R

cp /etc/postgresql/init-script/slave-config/* /var/lib/postgresql/data-slave
cp /etc/postgresql/init-script/config/pg_hba.conf /var/lib/postgresql/data
