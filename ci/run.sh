export KAFKA_VERSION=2.0.0
./kafka_test_setup.sh
bundle install
bundle exec rake vendor
