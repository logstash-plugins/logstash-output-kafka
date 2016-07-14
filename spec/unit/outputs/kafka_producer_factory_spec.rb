# encoding: utf-8
require 'logstash/outputs/kafka_producer_factory'
require 'java'

describe "outputs/kafka_producer_factory" do

  before do
      @props = java.util.Properties.new 
      @props.put("bootstrap.servers", "localhost:4242");
      @props.put("acks", "all");
      @props.put("retries", "0");
      @props.put("batch.size", "16384");
      @props.put("linger.ms", "1");
      @props.put("buffer.memory", "33554432");
      @props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
      @props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");
      props1 = @props.clone
      props2 = @props.clone
      props3 = @props.clone
      props3.put("bootstrap.servers", "localhost:4243");
      @producer1 = LogStash::Outputs::KafkaProducerFactory.instance.hold_producer(props1)
      @producer2 = LogStash::Outputs::KafkaProducerFactory.instance.hold_producer(props2)
      @producer3 = LogStash::Outputs::KafkaProducerFactory.instance.hold_producer(props3)
      LogStash::Outputs::KafkaProducerFactory.instance.release_producer(@producer2)
      LogStash::Outputs::KafkaProducerFactory.instance.release_producer(@producer3)
      @producer4 = LogStash::Outputs::KafkaProducerFactory.instance.hold_producer(props3)
      @producer5 = LogStash::Outputs::KafkaProducerFactory.instance.hold_producer(props2)
      
  end

  it 'should provide the same producer for two identical configs' do
    expect(@producer1).to equal(@producer2)
  end

  it 'should provide the different producer for two different configs' do
    expect(@producer1).not_to equal(@producer3)
  end

  it 'should provide different producer for two identical configs when use count has been set to 0 between producers creation' do
    expect(@producer4).not_to equal(@producer3)
  end

  it 'should provide the same producer for two identical configs when use count has not been set to 0 between producer creation' do
    expect(@producer5).to equal(@producer1)
  end

end
