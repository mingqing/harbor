#!/bin/bash
set -e

source $PWD/initdb.sh

CUR=$PWD
PG_VERSION_OLD=$1
PG_VERSION_NEW=$2

PGBINOLD="/usr/local/pg${PG_VERSION_OLD}/bin"

PGDATAOLD=${PGDATA}/pg${PG_VERSION_OLD}
PGDATANEW=${PGDATA}/pg${PG_VERSION_NEW}
# to handle the PG 9.6 only
if [ -s $PGDATA/PG_VERSION ]; then
         PGDATAOLD=$PGDATA
fi

#
# Init DB: $PGDATA is empty.
# Upgrade DB: 1, has $PGDATA\PG_VERSION. 2, has pg old version directory with PG_VERSION inside.
#
if [ "$(ls -A $PGDATA)" ]; then
        if [ ! -d $PGDATANEW ]; then
                if [ ! -d $PGDATAOLD ] || [ ! -s $PGDATAOLD/PG_VERSION ]; then
                        echo "incorrect data: $PGDATAOLD, make sure $PGDATAOLD is not empty and with PG_VERSION inside."
                        exit 1
                fi
                initPG $PGDATANEW false
                # because of the 'set -e', the upgrade failure will break execution.
                ./$CUR/upgrade.sh --old-bindir $PGBINOLD --old-datadir $PGDATAOLD --new-datadir $PGDATANEW
                echo "remove the $PGDATAOLD after upgrade success."
                if [ "$PGDATAOLD" = "$PGDATA" ]; then
                        find $PGDATA/* -prune ! -name pg${PG_VERSION_NEW} -exec rm -rf {} \;
                else
                        rm -rf $PGDATAOLD
                fi
        else
                echo "no need to upgrade postgres, launch it."
        fi
else
        initPG $PGDATANEW true
fi

POSTGRES_PARAMETER=''
file_env 'POSTGRES_MAX_CONNECTIONS' '1024'
# The max value of 'max_connections' is 262143
if [ $POSTGRES_MAX_CONNECTIONS -le 0 ] || [ $POSTGRES_MAX_CONNECTIONS -gt 262143 ]; then
        POSTGRES_MAX_CONNECTIONS=262143
fi

POSTGRES_PARAMETER="${POSTGRES_PARAMETER} -c max_connections=${POSTGRES_MAX_CONNECTIONS}"
exec postgres -D $PGDATANEW $POSTGRES_PARAMETER