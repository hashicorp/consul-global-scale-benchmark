#!/bin/bash

CONSUL_SHUTDOWN_VALUE="{{ key "consul-scalability-challenge/consul-shutdown-value" }}"
TEMP=$[( $RANDOM % 1000)]

echo "consul shutdown value: ${CONSUL_SHUTDOWN_VALUE}, random value: ${TEMP}"

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
INTERNAL_IP_ADDRESS=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/hostname)

if [ ${CONSUL_SHUTDOWN_VALUE} -gt ${TEMP} ];
then
  DATE="$(date)"
  echo "writing metadata to consul kv before shutdown....."
  echo "{\"date\": \"${DATE}\", \"instance_id\": \"${INSTANCE_ID}\", \"internal_ip_address\": \"${INTERNAL_IP_ADDRESS}\", \"hostname\": \"${HOSTNAME}\"}" | consul kv put consul-scalability-challenge/shutdown/${INSTANCE_ID} -
  echo "shutting down consul....."
  systemctl stop consul
else
  echo "no action taken"
fi