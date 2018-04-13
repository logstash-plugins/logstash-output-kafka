#!/bin/bash
# Setup Kafka and create test topics

set -ex

echo "Stopping Kafka broker"
kafka/bin/kafka-server-stop.sh
echo "Stopping zookeeper"
kafka/bin/zookeeper-server-stop.sh
echo "killing everything"
sleep 30s

PIDS=$(ps ax | grep -i 'kafka\.Kafka' | grep java | grep -v grep | awk '{print $1}')

if [ -z "$PIDS" ]; then
  echo "Kafka server stopped"
else
  echo "Killing Kafka server"
  kill -s KILL $PIDS
fi
