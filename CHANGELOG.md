## 5.1.5
  - Fix a bug where consumer was not correctly setup when `SASL_SSL` option was specified.

## 5.1.4
  - Docs: Move info about security features out of the compatibility matrix and into the main text.
  
## 5.1.3
  - Docs: Clarify compatibility matrix and remove it from the changelog to avoid duplication.

## 5.1.2
  - bump sl4j version dep to 1.7.21 to align with input plugin and kafka-clients maven deps

## 5.1.1
  - Docs: Update the doc to mention the plain codec instead of the json codec.

## 5.1.0
  - Add Kerberos authentication feature.

## 5.0.5
  - Fix logging

## 5.0.4
  - Update to 0.10.0.1

## 5.0.3
  - Internal: Gem cleanup

## 5.0.2
  - Declare plugin as threadsafe

## 5.0.1
  - Relax constraint on logstash-core-plugin-api to >= 1.60 <= 2.99

## 5.0.0
  - Kafka 0.10 broker producer

## 4.0.0
  - Republish all the gems under jruby.
  - Update the plugin to the version 2.0 of the plugin api, this change is required for Logstash 5.0 compatibility. See https://github.com/elastic/logstash/issues/5141
  
## 3.0.0
 - GA release of Kafka Output to support 0.9 broker

## 3.0.0.beta4
 - Fix Log4j warnings by setting up the logger (#62)

## 3.0.0.beta3
 - Use jar dependencies
 - Fixed snappy compression issue

## 3.0.0.beta2
 - Internal: Update gemspec dependency

## 2.0.4
  - Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash
  - [Internal] Pin jruby-kafka to v1.6 to match input
  
## 2.0.3
  - New dependency requirements for logstash-core for the 5.0 release

## 3.0.0.beta1
 - Note: breaking changes in this version, and not backward compatible with Kafka 0.8 broker. 
   Please read carefully before installing
 - Breaking: Changed default codec from json to plain. Json codec is really slow when used 
   with inputs because inputs by default are single threaded. This makes it a bad
   first user experience. Plain codec is a much better default. 
 - Moved internal APIs to use Kafka's Java API directly instead of jruby-kafka. This
   makes it consistent with logstash-input-kafka
 - Breaking: Change in configuration options
 - Added SSL options so you can connect securely to a 0.9 Kafka broker

## 2.0.2
 - [Internal] Pin jruby-kafka to v1.5

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully, 
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0

# ## 2.0.0.beta.1
 - Change to 0.8.2 version of Kafka producer. This will unfortunately break existing configuration, but has a lot of enhancements and fixes.
