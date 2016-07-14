# encoding: utf-8
require 'singleton'
require 'logstash/namespace'
require 'logstash/logging'
require 'java'
require 'logstash-output-kafka_jars.rb'
require 'thread'

#
# Simple class whicj is responsible for kafka producers management.
#
class LogStash::Outputs::KafkaProducerFactory  

  include Singleton

  def initialize
    # Initialize a mutex to use for thread safe
    @semaphore = Mutex.new
    # This var will be used to store producers objects, configurations and usage counter.
    @definitions = Array.new
  end

  def hold_producer(props)
    producer = nil
   
    @semaphore.synchronize {
      # Search for an existing definition matching the props parameter
      @definitions.each { |d|
        if d[:config].equals(props)
          producer = d[:producer]
          d[:usage] += 1
          break
        end
      }

      # If no definition have been found, we insert a new one
      if producer == nil
        producer = org.apache.kafka.clients.producer.KafkaProducer.new(props)
        @definitions.push({ :producer => producer, :usage => 1, :config => props})
      end
    }

    return producer
  end

  def release_producer(producer)
    definition = nil

    @semaphore.synchronize {
      # Search for the definition matching the specified producer
      @definitions.each { |d|
        if d[:producer].equals(producer)
          definition = d
          break
        end
      }

      definition[:usage] -= 1

      # Remove definitions that won't be used anymore
      if definition[:usage] == 0 
        @definitions.delete(definition)
      end     
    }

    # Close producer that won't be used anymore outside of the semaphore as this function could be long
    if definition[:usage] == 0
      definition[:producer].close
    end
  end
end
