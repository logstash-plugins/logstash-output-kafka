# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require 'logstash/outputs/kafka'
require 'jruby-kafka'
require 'json'

describe "outputs/kafka" do
  let (:simple_kafka_config) {{'topic_id' => 'test'}}
  let (:event) { LogStash::Event.new({'message' => 'hello', 'topic_name' => 'my_topic', 'host' => '172.0.0.1',
                                      '@timestamp' => LogStash::Timestamp.now}) }

  context 'when initializing' do
    it "should register" do
      output = LogStash::Plugin.lookup("output", "kafka").new(simple_kafka_config)
      expect {output.register}.to_not raise_error
    end

    it 'should populate kafka config with default values' do
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config)
      insist {kafka.bootstrap_servers} == 'localhost:9092'
      insist {kafka.topic_id} == 'test'
      insist {kafka.key_serializer} == 'org.apache.kafka.common.serialization.StringSerializer'
    end
  end

  context 'when outputting messages' do
    it 'should send logstash event to kafka broker' do
      expect_any_instance_of(Kafka::KafkaProducer).to receive(:send_msg)
        .with(simple_kafka_config['topic_id'], nil, nil, event.to_hash.to_json)
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config)
      kafka.register
      kafka.receive(event)
    end

    it 'should support Event#sprintf placeholders in topic_id' do
      topic_field = 'topic_name'
      expect_any_instance_of(Kafka::KafkaProducer).to receive(:send_msg)
        .with(event[topic_field], nil, nil, event.to_hash.to_json)
      kafka = LogStash::Outputs::Kafka.new({'topic_id' => "%{#{topic_field}}"})
      kafka.register
      kafka.receive(event)
    end

    it 'should support field referenced message_keys' do
      expect_any_instance_of(Kafka::KafkaProducer).to receive(:send_msg)
        .with(simple_kafka_config['topic_id'], nil, event['host'], event.to_hash.to_json)
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config.merge({"message_key" => "%{host}"}))
      kafka.register
      kafka.receive(event)
    end
  end
end
