# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require 'logstash/outputs/kafka'
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
      expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
        .with(an_instance_of(org.apache.kafka.clients.producer.ProducerRecord)).and_call_original
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config)
      kafka.register
      kafka.multi_receive([event])
    end

    it 'should support Event#sprintf placeholders in topic_id' do
      topic_field = 'topic_name'
      expect(org.apache.kafka.clients.producer.ProducerRecord).to receive(:new)
        .with("my_topic", event.to_s).and_call_original
      expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send).and_call_original
      kafka = LogStash::Outputs::Kafka.new({'topic_id' => "%{#{topic_field}}"})
      kafka.register
      kafka.multi_receive([event])
    end

    it 'should support field referenced message_keys' do
      expect(org.apache.kafka.clients.producer.ProducerRecord).to receive(:new)
        .with("test", "172.0.0.1", event.to_s).and_call_original
      expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send).and_call_original
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config.merge({"message_key" => "%{host}"}))
      kafka.register
      kafka.multi_receive([event])
    end

    it 'should raise config error when truststore location is not set and ssl is enabled' do
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config.merge("security_protocol" => "SSL"))
      expect { kafka.register }.to raise_error(LogStash::ConfigurationError, /ssl_truststore_location must be set when SSL is enabled/)
    end
  end
  
  context "when KafkaProducer#send() raises an exception" do
    let(:failcount) { (rand * 10).to_i }
    let(:sendcount) { failcount + 1 }

    let(:exception_classes) { [
      org.apache.kafka.common.errors.TimeoutException,
      org.apache.kafka.common.errors.InterruptException,
      org.apache.kafka.common.errors.SerializationException
    ] }

    before do
      count = 0
      expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
        .exactly(sendcount).times
        .and_wrap_original do |m, *args|
        if count < failcount # fail 'failcount' times in a row.
          count += 1
          # Pick an exception at random
          raise exception_classes.shuffle.first.new("injected exception for testing")
        else
          m.call(*args) # call original
        end
      end
    end

    it "should retry until successful" do
      kafka = LogStash::Outputs::Kafka.new(simple_kafka_config)
      kafka.register
      kafka.multi_receive([event])
    end
  end

  context "when a send fails" do
    context "and the default retries behavior is used" do
      # Fail this many times and then finally succeed.
      let(:failcount) { (rand * 10).to_i }

      # Expect KafkaProducer.send() to get called again after every failure, plus the successful one.
      let(:sendcount) { failcount + 1 }

      it "should retry until successful" do
        count = 0;

        expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
              .exactly(sendcount).times
              .and_wrap_original do |m, *args|
          if count < failcount
            count += 1
            # inject some failures.

            # Return a custom Future that will raise an exception to simulate a Kafka send() problem.
            future = java.util.concurrent.FutureTask.new { raise "Failed" }
            future.run
            future
          else
            m.call(*args)
          end
        end
        kafka = LogStash::Outputs::Kafka.new(simple_kafka_config)
        kafka.register
        kafka.multi_receive([event])
      end
    end

    context 'when retries is 0' do
      let(:retries) { 0  }
      let(:max_sends) { 1 }

      it "should should only send once" do
        expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
                                                                                       .once
                                                                                       .and_wrap_original do |m, *args|
          # Always fail.
          future = java.util.concurrent.FutureTask.new { raise "Failed" }
          future.run
          future
        end
        kafka = LogStash::Outputs::Kafka.new(simple_kafka_config.merge("retries" => retries))
        kafka.register
        kafka.multi_receive([event])
      end

      it 'should not sleep' do
        expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
                                                                                       .once
                                                                                       .and_wrap_original do |m, *args|
          # Always fail.
          future = java.util.concurrent.FutureTask.new { raise "Failed" }
          future.run
          future
        end

        kafka = LogStash::Outputs::Kafka.new(simple_kafka_config.merge("retries" => retries))
        expect(kafka).not_to receive(:sleep).with(anything)
        kafka.register
        kafka.multi_receive([event])
      end
    end

    context "and when retries is set by the user" do
      let(:retries) { (rand * 10).to_i }
      let(:max_sends) { retries + 1 }

      it "should give up after retries are exhausted" do
        expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
              .at_most(max_sends).times
              .and_wrap_original do |m, *args|
          # Always fail.
          future = java.util.concurrent.FutureTask.new { raise "Failed" }
          future.run
          future
        end
        kafka = LogStash::Outputs::Kafka.new(simple_kafka_config.merge("retries" => retries))
        kafka.register
        kafka.multi_receive([event])
      end

      it 'should only sleep retries number of times' do
        expect_any_instance_of(org.apache.kafka.clients.producer.KafkaProducer).to receive(:send)
                                                                                       .at_most(max_sends)
                                                                                       .and_wrap_original do |m, *args|
          # Always fail.
          future = java.util.concurrent.FutureTask.new { raise "Failed" }
          future.run
          future
        end
        kafka = LogStash::Outputs::Kafka.new(simple_kafka_config.merge("retries" => retries))
        expect(kafka).to receive(:sleep).exactly(retries).times
        kafka.register
        kafka.multi_receive([event])
      end
    end
  end
end
