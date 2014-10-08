Gem::Specification.new do |s|

  s.name            = 'logstash-output-kafka'
  s.version         = '0.1.0'
  s.licenses        = ['Apache License (2.0)']
  s.summary         = 'Output events to a Kafka topic. This uses the Kafka Producer API to write messages to a topic on the broker'
  s.description     = 'Output events to a Kafka topic. This uses the Kafka Producer API to write messages to a topic on the broker'
  s.authors         = ['Elasticsearch']
  s.email           = 'richard.pijnenburg@elasticsearch.com'
  s.homepage        = 'http://logstash.net/'
  s.require_paths = ['lib']

  # Files
  s.files = `git ls-files`.split($\)

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { 'logstash_plugin' => 'true', 'group' => 'output'}

  # Jar dependencies
  s.requirements << "jar 'org.apache.kafka:kafka_2.10', '0.8.1.1'"

  # Gem dependencies
  s.add_runtime_dependency 'logstash', '>= 1.4.0', '< 2.0.0'
  s.add_runtime_dependency 'jar-dependencies', ['~> 0.1.0']

  s.add_runtime_dependency 'jruby-kafka', ['>=0.2.1']

end
