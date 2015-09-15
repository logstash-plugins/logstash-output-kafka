# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require 'logstash/outputs/kafka'
require 'longshoreman'
require 'jruby-kafka'
require 'json'
require 'poseidon'

CONTAINER_NAME = "kafka-#{rand(999).to_s}"
IMAGE_NAME = 'spotify/kafka'
IMAGE_TAG = 'latest'
KAFKA_PORT = 9092
KAFKA_VERSION = "0.8.2.1"
KAFKA_SCALA_VERSION = "2.11"

RSpec.configure do |config|
  config.before(:all, :integration => true) do
    @ls = begin
            ls = Longshoreman.new
            ls.container.get(CONTAINER_NAME)
            ls
          rescue Docker::Error::NotFoundError
            Longshoreman.pull_image(IMAGE_NAME, IMAGE_TAG)
            Longshoreman.new("#{IMAGE_NAME}:#{IMAGE_TAG}", CONTAINER_NAME,
                             { "ENV" => [ "ADVERTISED_HOST=#{Longshoreman.new.get_host_ip}", "ADVERTISED_PORT=#{KAFKA_PORT}"],
                               "PortBindings" => { "#{KAFKA_PORT}/tcp" => [{ "HostPort" => "#{KAFKA_PORT}" }]}})
          end
    @kafka_host = @ls.get_host_ip
    @kafka_port = @ls.container.rport(9092)
    @zk_port = @ls.container.rport(2181)
  end

  config.after(:suite) do
    begin
      ls = Longshoreman::new
      ls.container.get(CONTAINER_NAME)
      ls.cleanup
    rescue Docker::Error::NotFoundError, Excon::Errors::SocketError
    end
  end
end

describe "outputs/kafka", :integration => true do
  let(:test_topic) { 'test' }
  let(:base_config) { {'client_id' => 'spectest', 'bootstrap_servers' => "#{@kafka_host}:#{@kafka_port}"} }
  let(:event) { LogStash::Event.new({'message' => 'hello', '@timestamp' => LogStash::Timestamp.at(0) }) }


  context 'when outputting messages' do
    let(:num_events) { 3 }
    let(:consumer) do
      Poseidon::PartitionConsumer.new("my_test_consumer", @kafka_host, @kafka_port,
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
      Poseidon::PartitionConsumer.new("my_test_consumer", @kafka_host, @kafka_port,
                                      test_topic, 0, :earliest_offset)
    end
    let!(:consumer1) do
      Poseidon::PartitionConsumer.new("my_test_consumer", @kafka_host, @kafka_port,
                                      test_topic, 1, :earliest_offset)
    end

    before :each do
      command = ["/opt/kafka_#{KAFKA_SCALA_VERSION}-#{KAFKA_VERSION}/bin/kafka-topics.sh", "--create", "--topic", "#{test_topic}", "--partitions", "2", "--zookeeper", "#{@kafka_host}:#{@zk_port}", "--replication-factor", "1"]
      @ls.container.raw.exec(command)

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
