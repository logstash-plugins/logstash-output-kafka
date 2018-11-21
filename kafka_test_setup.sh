#!/bin/bash
# Setup Kafka and create test topics

set -ex
if [ -n "${KAFKA_VERSION+1}" ]; then
  echo "KAFKA_VERSION is $KAFKA_VERSION"
else
   KAFKA_VERSION=2.0.1
fi

echo "Downloading Kafka version $KAFKA_VERSION"
curl -s -o kafka.tgz "http://ftp.wayne.edu/apache/kafka/$KAFKA_VERSION/kafka_2.11-$KAFKA_VERSION.tgz"
mkdir kafka && tar xzf kafka.tgz -C kafka --strip-components 1

echo "Starting ZooKeeper"
kafka/bin/zookeeper-server-start.sh -daemon kafka/config/zookeeper.properties
sleep 10
echo "Starting Kafka broker"
kafka/bin/kafka-server-start.sh -daemon kafka/config/server.properties
sleep 10

echo "Setting up test topics with test data"

kafka/bin/kafka-topics.sh --create --partitions 1 --replication-factor 1 --topic topic1 --zookeeper localhost:2181
kafka/bin/kafka-topics.sh --create --partitions 2 --replication-factor 1 --topic topic2 --zookeeper localhost:2181
kafka/bin/kafka-topics.sh --create --partitions 1 --replication-factor 1 --topic gzip_topic --zookeeper localhost:2181
kafka/bin/kafka-topics.sh --create --partitions 1 --replication-factor 1 --topic snappy_topic --zookeeper localhost:2181
kafka/bin/kafka-topics.sh --create --partitions 1 --replication-factor 1 --topic lz4_topic --zookeeper localhost:2181
kafka/bin/kafka-topics.sh --create --partitions 3 --replication-factor 1 --topic topic3 --zookeeper localhost:2181
