# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require 'logstash/outputs/kafka'
require 'json'

describe "outputs/kafka" do
  let (:simple_kafka_config) {{'topic_id' => 'test'}}
  let (:event) { LogStash::Event.new({'message' => 'hello', 'topic_name' => 'my_topic', 'host' => '172.0.0.1',
                                      '@timestamp' => LogStash::Timestamp.now, 'other_timestamp' => 1487669184685}) }

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
      expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
        .with(an_instance_of(org.apache.kafka.clients.producer.ProducerRecord))
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config)
      kafka.register
      kafka.receive(event)
    end

    it 'should support Event#sprintf placeholders in topic_id' do
      topic_field = 'topic_name'
      expect(org.apache.kafka.clients.producer.ProducerRecord).to receive(:new)
        .with("my_topic", nil, nil, nil, event.to_s)
      expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
      kafka = LogStash::Outputs::Kafka.new({'topic_id' => "%{#{topic_field}}"})
      kafka.register
      kafka.receive(event)
    end

    it 'should support field referenced message_keys' do
      expect(org.apache.kafka.clients.producer.ProducerRecord).to receive(:new)
        .with("test", nil, nil, "172.0.0.1", event.to_s)
      expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config.merge({"message_key" => "%{host}"}))
      kafka.register
      kafka.receive(event)
    end

    it 'should support timestamp from specified message field' do
      expect(org.apache.kafka.clients.producer.ProducerRecord).to receive(:new)
        .with("test", nil, event.get('@timestamp').time.to_i, nil, event.to_s)
      expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config.merge({"message_timestamp" => "@timestamp"}))
      kafka.register
      kafka.receive(event)
    end

    it 'should support field referenced message_timestamp' do
      expect(org.apache.kafka.clients.producer.ProducerRecord).to receive(:new)
        .with("test", nil, event.get('other_timestamp').to_i, nil, event.to_s)
      expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config.merge({"message_timestamp" => "%{other_timestamp}"}))
      kafka.register
      kafka.receive(event)
    end

    it 'should raise config error when truststore location is not set and ssl is enabled' do
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config.merge({"ssl" => "true"}))
      expect { kafka.register }.to raise_error(LogStash::ConfigurationError, /ssl_truststore_location must be set when SSL is enabled/)
    end
  end
end
