#!/bin/bash
# Simple script to run the POC test
# This script sets up the environment and runs the test

cd /var/www/community
bundle exec rails runner temp/test_redis_tls_runner.rb

