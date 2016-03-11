require 'logstash/namespace'
require 'logstash/outputs/base'
require 'java'
require 'logstash-output-kafka_jars.rb'

# Write events to a Kafka topic. This uses the Kafka Producer API to write messages to a topic on
# the broker.
#
# The only required configuration is the topic name. The default codec is json,
# so events will be persisted on the broker in json format. If you select a codec of plain,
# Logstash will encode your messages with not only the message but also with a timestamp and
# hostname. If you do not want anything but your message passing through, you should make the output
# configuration something like:
# [source,ruby]
#     output {
#       kafka {
#         codec => plain {
#            format => "%{message}"
#         }
#       }
#     }
# For more information see http://kafka.apache.org/documentation.html#theproducer
#
# Kafka producer configuration: http://kafka.apache.org/documentation.html#newproducerconfigs
class LogStash::Outputs::Kafka < LogStash::Outputs::Base
  config_name 'kafka'

  default :codec, 'plain'

  # The number of acknowledgments the producer requires the leader to have received
  # before considering a request complete.
  #
  # acks=0,   the producer will not wait for any acknowledgment from the server at all.
  # acks=1,   This will mean the leader will write the record to its local log but
  #           will respond without awaiting full acknowledgement from all followers.
  # acks=all, This means the leader will wait for the full set of in-sync replicas to acknowledge the record.
  config :acks, :validate => ["0", "1", "all"], :default => "1"
  # The producer will attempt to batch records together into fewer requests whenever multiple
  # records are being sent to the same partition. This helps performance on both the client
  # and the server. This configuration controls the default batch size in bytes.
  config :batch_size, :validate => :number, :default => 16384
  # This is for bootstrapping and the producer will only use it for getting metadata (topics,
  # partitions and replicas). The socket connections for sending the actual data will be
  # established based on the broker information returned in the metadata. The format is
  # `host1:port1,host2:port2`, and the list can be a subset of brokers or a VIP pointing to a
  # subset of brokers.
  config :bootstrap_servers, :validate => :string, :default => 'localhost:9092'
  # When our memory buffer is exhausted we must either stop accepting new
  # records (block) or throw errors. By default this setting is true and we block,
  # however in some scenarios blocking is not desirable and it is better to immediately give an error.
  config :block_on_buffer_full, :validate => :boolean, :default => true, :deprecated => "This config will be removed in a future release"
  # The total bytes of memory the producer can use to buffer records waiting to be sent to the server.
  config :buffer_memory, :validate => :number, :default => 33554432
  # The compression type for all data generated by the producer.
  # The default is none (i.e. no compression). Valid values are none, gzip, or snappy.
  config :compression_type, :validate => ["none", "gzip", "snappy"], :default => "none"
  # The id string to pass to the server when making requests.
  # The purpose of this is to be able to track the source of requests beyond just
  # ip/port by allowing a logical application name to be included with the request
  config :client_id, :validate => :string
  # Serializer class for the key of the message
  config :key_serializer, :validate => :string, :default => 'org.apache.kafka.common.serialization.StringSerializer'
  # The producer groups together any records that arrive in between request
  # transmissions into a single batched request. Normally this occurs only under
  # load when records arrive faster than they can be sent out. However in some circumstances
  # the client may want to reduce the number of requests even under moderate load.
  # This setting accomplishes this by adding a small amount of artificial delay—that is,
  # rather than immediately sending out a record the producer will wait for up to the given delay
  # to allow other records to be sent so that the sends can be batched together.
  config :linger_ms, :validate => :number, :default => 0
  # The maximum size of a request
  config :max_request_size, :validate => :number, :default => 1048576
  # The key for the message
  config :message_key, :validate => :string
  # the timeout setting for initial metadata request to fetch topic metadata.
  config :metadata_fetch_timeout_ms, :validate => :number, :default => 60000
  # the max time in milliseconds before a metadata refresh is forced.
  config :metadata_max_age_ms, :validate => :number, :default => 300000
  # The size of the TCP receive buffer to use when reading data
  config :receive_buffer_bytes, :validate => :number, :default => 32768
  # The amount of time to wait before attempting to reconnect to a given host when a connection fails.
  config :reconnect_backoff_ms, :validate => :number, :default => 10
  # The configuration controls the maximum amount of time the client will wait
  # for the response of a request. If the response is not received before the timeout
  # elapses the client will resend the request if necessary or fail the request if
  # retries are exhausted.
  config :request_timeout_ms, :validate => :string
  # Setting a value greater than zero will cause the client to
  # resend any record whose send fails with a potentially transient error.
  config :retries, :validate => :number, :default => 0
  # The amount of time to wait before attempting to retry a failed produce request to a given topic partition.
  config :retry_backoff_ms, :validate => :number, :default => 100
  # The size of the TCP send buffer to use when sending data.
  config :send_buffer_bytes, :validate => :number, :default => 131072
  # Enable SSL/TLS secured communication to Kafka broker. Note that secure communication 
  # is only available with a broker running v0.9 of Kafka.
  config :ssl, :validate => :boolean, :default => false
  # The JKS truststore path to validate the Kafka broker's certificate.
  config :ssl_truststore_location, :validate => :path
  # The truststore password
  config :ssl_truststore_password, :validate => :password
  # If client authentication is required, this setting stores the keystore path.
  config :ssl_keystore_location, :validate => :path
  # If client authentication is required, this setting stores the keystore password
  config :ssl_keystore_password, :validate => :password
  # The configuration controls the maximum amount of time the server will wait for acknowledgments
  # from followers to meet the acknowledgment requirements the producer has specified with the
  # acks configuration. If the requested number of acknowledgments are not met when the timeout
  # elapses an error will be returned. This timeout is measured on the server side and does not
  # include the network latency of the request.
  config :timeout_ms, :validate => :number, :default => 30000, :deprecated => "This config will be removed in a future release. Please use request_timeout_ms"
  # The topic to produce messages to
  config :topic_id, :validate => :string, :required => true
  # Serializer class for the value of the message
  config :value_serializer, :validate => :string, :default => 'org.apache.kafka.common.serialization.StringSerializer'

  public
  def register
    if (defined?(@@producer) == nil) or @@producer.nil?
      @logger.debug('First call to the Kafka output class. Kafka producer will be created.')
      @@producer = create_producer
    end

    @codec.on_event do |event, data|
      begin
        if @message_key.nil?
          record = org.apache.kafka.clients.producer.ProducerRecord.new(event.sprintf(@topic_id), data)
        else
          record = org.apache.kafka.clients.producer.ProducerRecord.new(event.sprintf(@topic_id), event.sprintf(@message_key), data)
        end
        @@producer.send(record)
      rescue LogStash::ShutdownSignal
        @logger.info('Kafka producer got shutdown signal')
      rescue => e
        @logger.warn('kafka producer threw exception, restarting',
                     :exception => e)
      end
    end

  end # def register

  def receive(event)
    if event == LogStash::SHUTDOWN
      return
    end
    @codec.encode(event)
  end

  def close
    @@producer.close
  end

  private
  def create_producer
    begin
      props = java.util.Properties.new
      kafka = org.apache.kafka.clients.producer.ProducerConfig

      props.put(kafka::ACKS_CONFIG, acks)
      props.put(kafka::BATCH_SIZE_CONFIG, batch_size.to_s)
      props.put(kafka::BOOTSTRAP_SERVERS_CONFIG, bootstrap_servers)
      props.put(kafka::BUFFER_MEMORY_CONFIG, buffer_memory.to_s)
      props.put(kafka::COMPRESSION_TYPE_CONFIG, compression_type)
      props.put(kafka::CLIENT_ID_CONFIG, client_id) unless client_id.nil?
      props.put(kafka::KEY_SERIALIZER_CLASS_CONFIG, key_serializer)
      props.put(kafka::LINGER_MS_CONFIG, linger_ms.to_s)
      props.put(kafka::MAX_REQUEST_SIZE_CONFIG, max_request_size.to_s)
      props.put(kafka::RECONNECT_BACKOFF_MS_CONFIG, reconnect_backoff_ms) unless reconnect_backoff_ms.nil?
      props.put(kafka::REQUEST_TIMEOUT_MS_CONFIG, request_timeout_ms) unless request_timeout_ms.nil?
      props.put(kafka::RETRIES_CONFIG, retries.to_s)
      props.put(kafka::RETRY_BACKOFF_MS_CONFIG, retry_backoff_ms.to_s)
      props.put(kafka::SEND_BUFFER_CONFIG, send_buffer_bytes.to_s)
      props.put(kafka::VALUE_SERIALIZER_CLASS_CONFIG, value_serializer)
      
      if ssl
        if ssl_truststore_location.nil?
          raise LogStash::ConfigurationError, "ssl_truststore_location must be set when SSL is enabled"
        end
        props.put("security.protocol", "SSL")
        props.put("ssl.truststore.location", ssl_truststore_location)
        props.put("ssl.truststore.password", ssl_truststore_password.value) unless ssl_truststore_password.nil?

        #Client auth stuff
        props.put("ssl.keystore.location", ssl_keystore_location) unless ssl_keystore_location.nil?
        props.put("ssl.keystore.password", ssl_keystore_password.value) unless ssl_keystore_password.nil?
      end

      org.apache.kafka.clients.producer.KafkaProducer.new(props)
    rescue => e
      logger.error("Unable to create Kafka producer from given configuration", :kafka_error_message => e)
      raise e
    end
  end

end #class LogStash::Outputs::Kafka
