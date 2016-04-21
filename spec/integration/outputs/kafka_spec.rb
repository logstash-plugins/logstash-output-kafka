# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require 'logstash/outputs/kafka'
require 'jruby-kafka'
require 'json'
require 'poseidon'

describe "outputs/kafka", :integration => true do
  let(:test_topic) { 'test' }
  let(:base_config) { {'client_id' => 'spectest' } }
  let(:event) { LogStash::Event.new({'message' => 'hello', '@timestamp' => LogStash::Timestamp.at(0) }) }


  context 'when outputting messages' do
    let(:num_events) { 3 }
    let(:consumer) do
      Poseidon::PartitionConsumer.new("my_test_consumer", "localhost", 9092,
                                      test_topic, 0, :earliest_offset)
    end
    subject do
      consumer.fetch
    end

    before :each do
      config = base_config.merge({"topic_id" => test_topic})
      kafka = LogStash::Outputs::Kafka.new(config)
      kafka.register
      num_events.times do kafka.receive(event) end
      kafka.close
    end

    it 'should have data integrity' do
      expect(subject.size).to eq(num_events)
      subject.each do |m|
        expect(m.value).to eq(event.to_json)
      end
    end
  end

  context 'when setting message_key' do
    let(:num_events) { 10 }
    let(:test_topic) { 'test2' }
    let!(:consumer0) do
      Poseidon::PartitionConsumer.new("my_test_consumer2", "localhost", 9092,
                                      test_topic, 0, :earliest_offset)
    end
    let!(:consumer1) do
      Poseidon::PartitionConsumer.new("my_test_consumer2", "localhost", 9092,
                                      test_topic, 1, :earliest_offset)
    end

    before :each do
      config = base_config.merge({"topic_id" => test_topic, "message_key" => "static_key"})
      kafka = LogStash::Outputs::Kafka.new(config)
      kafka.register
      num_events.times do kafka.receive(event) end
      kafka.close
    end

    it 'should send all events to one partition' do
      expect(consumer0.fetch.size == num_events || consumer1.fetch.size == num_events).to be true
    end
  end
end
