# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require 'logstash/outputs/kafka'
require 'json'
require 'poseidon'

describe "outputs/kafka", :integration => true do
  let(:kafka_host) { 'localhost' }
  let(:kafka_port) { 9092 }
  let(:num_events) { 10 }
  let(:base_config) { {'client_id' => 'kafkaoutputspec'} }
  let(:event) { LogStash::Event.new({'message' => '183.60.215.50 - - [11/Sep/2014:22:00:00 +0000] "GET /scripts/netcat-webserver HTTP/1.1" 200 182 "-" "Mozilla/5.0 (compatible; EasouSpider; +http://www.easou.com/search/spider.html)"', '@timestamp' => LogStash::Timestamp.at(0) }) }


  context 'when outputting messages serialized as String' do
    let(:test_topic) { 'topic1' }
    let(:num_events) { 3 }
    let(:consumer) do
      Poseidon::PartitionConsumer.new("my_test_consumer", kafka_host, kafka_port,
                                      test_topic, 0, :earliest_offset)
    end
    subject do
      consumer.fetch
    end

    before :each do
      config = base_config.merge({"topic_id" => test_topic})
      load_kafka_data(config)
    end

    it 'should have data integrity' do
      expect(subject.size).to eq(num_events)
      subject.each do |m|
        expect(m.value).to eq(event.to_s)
      end
    end

  end

  context 'when outputting messages serialized as Byte Array' do
    let(:test_topic) { 'topic1b' }
    let(:num_events) { 3 }
    let(:consumer) do
      Poseidon::PartitionConsumer.new("my_test_consumer", kafka_host, kafka_port,
                                      test_topic, 0, :earliest_offset)
    end
    subject do
      consumer.fetch
    end

    before :each do
      config = base_config.merge(
        {
          "topic_id" => test_topic,
          "value_serializer" => 'org.apache.kafka.common.serialization.ByteArraySerializer'
        }
      )
      load_kafka_data(config)
    end

    it 'should have data integrity' do
      expect(subject.size).to eq(num_events)
      subject.each do |m|
        expect(m.value).to eq(event.to_s)
      end
    end

  end

  context 'when setting message_key' do
    let(:num_events) { 10 }
    let(:test_topic) { 'topic2' }
    let!(:consumer0) do
      Poseidon::PartitionConsumer.new("my_test_consumer", kafka_host, kafka_port,
                                      test_topic, 0, :earliest_offset)
    end
    let!(:consumer1) do
      Poseidon::PartitionConsumer.new("my_test_consumer", kafka_host, kafka_port,
                                      test_topic, 1, :earliest_offset)
    end

    before :each do
      config = base_config.merge({"topic_id" => test_topic, "message_key" => "static_key"})
      load_kafka_data(config)
    end

    it 'should send all events to one partition' do
      expect(consumer0.fetch.size == num_events || consumer1.fetch.size == num_events).to be true
    end
  end

  context 'when using gzip compression' do
    let(:test_topic) { 'gzip_topic' }
    let!(:consumer) do
      Poseidon::PartitionConsumer.new("my_test_consumer", kafka_host, kafka_port,
                                      test_topic, 0, :earliest_offset)
    end
    subject do
      consumer.fetch
    end

    before :each do
      config = base_config.merge({"topic_id" => test_topic, "compression_type" => "gzip"})
      load_kafka_data(config)
    end

    it 'should have data integrity' do
      expect(subject.size).to eq(num_events)
      subject.each do |m|
        expect(m.value).to eq(event.to_s)
      end
    end
  end

  context 'when using snappy compression' do
    let(:test_topic) { 'snappy_topic' }
    let!(:consumer) do
      Poseidon::PartitionConsumer.new("my_test_consumer", kafka_host, kafka_port,
                                      test_topic, 0, :earliest_offset)
    end
    subject do
      consumer.fetch
    end

    before :each do
      config = base_config.merge({"topic_id" => test_topic, "compression_type" => "snappy"})
      load_kafka_data(config)
    end

    it 'should have data integrity' do
      expect(subject.size).to eq(num_events)
      subject.each do |m|
        expect(m.value).to eq(event.to_s)
      end
    end
  end

  context 'when using zstd compression' do
    let(:test_topic) { 'zstd_topic' }

    before :each do
      config = base_config.merge({"topic_id" => test_topic, "compression_type" => "zstd"})
      load_kafka_data(config)
    end
  end

  context 'when using LZ4 compression' do
    let(:test_topic) { 'lz4_topic' }

    before :each do
      config = base_config.merge({"topic_id" => test_topic, "compression_type" => "lz4"})
      load_kafka_data(config)
    end
  end

  context 'when using multi partition topic' do
    let(:num_events) { 10 }
    let(:test_topic) { 'topic3' }
    let!(:consumer0) do
      Poseidon::PartitionConsumer.new("my_test_consumer", kafka_host, kafka_port,
                                      test_topic, 0, :earliest_offset)
    end
    let!(:consumer1) do
      Poseidon::PartitionConsumer.new("my_test_consumer", kafka_host, kafka_port,
                                      test_topic, 1, :earliest_offset)
    end

    let!(:consumer2) do
      Poseidon::PartitionConsumer.new("my_test_consumer", kafka_host, kafka_port,
                                      test_topic, 2, :earliest_offset)
    end

    before :each do
      config = base_config.merge({"topic_id" => test_topic})
      load_kafka_data(config)
    end

    it 'should distribute events to all partition' do
      consumer0_records = consumer0.fetch
      consumer1_records = consumer1.fetch
      consumer2_records = consumer2.fetch

      expect(consumer0_records.size > 1 &&
        consumer1_records.size > 1 &&
          consumer2_records.size > 1).to be true

      all_records = consumer0_records + consumer1_records + consumer2_records
      expect(all_records.size).to eq(num_events)
      all_records.each do |m|
        expect(m.value).to eq(event.to_s)
      end
    end
  end

  def load_kafka_data(config)
    kafka = LogStash::Outputs::Kafka.new(config)
    kafka.register
    kafka.multi_receive(num_events.times.collect { event })
    kafka.close
  end

end
