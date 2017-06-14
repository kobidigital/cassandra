#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
if [ "${1:0:1}" = '-' ]; then
  set -- cassandra -f "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'cassandra' -a "$(id -u)" = '0' ]; then
  chown -R cassandra /var/lib/cassandra /var/log/cassandra "$CASSANDRA_CONFIG"
  exec gosu cassandra "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'cassandra' ]; then

  sleep $[ ( $RANDOM % 10 ) + 1]

  : ${CASSANDRA_RPC_ADDRESS='0.0.0.0'}
  : ${HOST_COMMAND='hostname --ip-address'}

  : ${SEEDS_COMMAND="echo \$CASSANDRA_BROADCAST_ADDRESS"}

  # Listen Address
  : ${CASSANDRA_LISTEN_ADDRESS_COMMAND=$HOST_COMMAND}
  : ${CASSANDRA_LISTEN_ADDRESS='auto'}
  if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
    CASSANDRA_LISTEN_ADDRESS=$(eval $CASSANDRA_LISTEN_ADDRESS_COMMAND)
  fi

  # Broadcast Address
  : ${CASSANDRA_BROADCAST_ADDRESS_COMMAND=$HOST_COMMAND}
  : ${CASSANDRA_BROADCAST_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"}

  if [ "$CASSANDRA_BROADCAST_ADDRESS" = 'auto' ]; then
    CASSANDRA_BROADCAST_ADDRESS=$(eval $CASSANDRA_BROADCAST_ADDRESS_COMMAND)
  fi
  : ${CASSANDRA_BROADCAST_RPC_ADDRESS:=$CASSANDRA_BROADCAST_ADDRESS}

  # Seeds
  if [ -n "${CASSANDRA_NAME:+1}" ]; then
    : ${CASSANDRA_SEEDS="cassandra"}
  fi

  if [ "$CASSANDRA_SEEDS" = 'auto' ]; then
    echo "evaluating cassandra seeds with $SEEDS_COMMAND"
    CASSANDRA_SEEDS=$(eval $SEEDS_COMMAND)
  fi
  
  sed -ri 's/(- seeds:).*/\1 "'"$CASSANDRA_SEEDS"'"/' "$CASSANDRA_CONFIG/cassandra.yaml"

  # Substitution
  for yaml in \
    broadcast_address \
    broadcast_rpc_address \
    cluster_name \
    endpoint_snitch \
    listen_address \
    listen_interface \
    num_tokens \
    rpc_address \
    start_rpc \
  ; do
    var="CASSANDRA_${yaml^^}"
    val="${!var}"
    if [ "$val" ]; then
      sed -ri 's/^(# )?('"$yaml"':).*/\2 '"$val"'/' "$CASSANDRA_CONFIG/cassandra.yaml"
    fi
  done

  for rackdc in dc rack; do
    var="CASSANDRA_${rackdc^^}"
    val="${!var}"
    if [ "$val" ]; then
      sed -ri 's/^('"$rackdc"'=).*/\1 '"$val"'/' "$CASSANDRA_CONFIG/cassandra-rackdc.properties"
    fi
  done
fi

exec "$@"
