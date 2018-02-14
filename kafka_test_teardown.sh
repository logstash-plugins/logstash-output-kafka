#!/bin/bash
# Setup Kafka and create test topics

set -ex

echo "Stopping Kafka broker"
kafka/bin/kafka-server-stop.sh
echo "Stopping zookeeper"
kafka/bin/zookeeper-server-stop.sh
echo "killing everything"
sleep 30s
ps aux
kill $(jobs -p)
ps aux
