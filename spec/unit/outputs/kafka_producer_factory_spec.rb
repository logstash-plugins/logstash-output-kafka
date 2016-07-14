# encoding: utf-8
require 'logstash/outputs/kafka_producer_factory'
require 'java'

describe "outputs/kafka_producer_factory" do

  before do
      props = java.util.Properties.new 
      props.put("bootstrap.servers", "localhost:4242");
      props.put("acks", "all");
      props.put("retries", "0");
      props.put("batch.size", "16384");
      props.put("linger.ms", "1");
      props.put("buffer.memory", "33554432");
      props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
      props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");
      props1 = props.clone
      props2 = props.clone
      props3 = props.clone
      props3.put("bootstrap.servers", "localhost:4244");
      @producer1 = LogStash::Outputs::KafkaProducerFactory.instance.hold_producer(props1)
      @producer2 = LogStash::Outputs::KafkaProducerFactory.instance.hold_producer(props2)
      @producer3 = LogStash::Outputs::KafkaProducerFactory.instance.hold_producer(props3)
  end

  it 'should provide the same producer for two identical configs' do
    expect(@producer1).to equal(@producer2)
  end

  it 'should provide the different producer for two different configs' do
    expect(@producer1).not_to equal(@producer3)
  end

end
