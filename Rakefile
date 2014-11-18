require 'gem_publisher'

desc 'Publish gem to RubyGems.org'
task :publish_gem do |t|
  gem = GemPublisher.publish_if_updated('logstash-output-kafka.gemspec', :rubygems)
  puts "Published #{gem}" if gem
end

task :default do
  system('rake -T')
end
require "logstash/devutils/rake"
