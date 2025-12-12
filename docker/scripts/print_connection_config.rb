#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../config/environment"

config = ActiveRecord::Base.connection_pool.db_config.configuration_hash

puts "=== FULL CONNECTION CONFIGURATION ==="
puts ""
config.each do |k, v|
  if k == "password"
    puts "#{k}: [REDACTED - length: #{v.to_s.length}]"
  else
    puts "#{k}: #{v}"
  end
end

puts ""
puts "=== CONNECTION STRING (without password) ==="
conn_str = "postgresql://#{config["username"]}@#{config["host"]}:#{config["port"]}/#{config["database"]}"
conn_str += "?sslmode=#{config["sslmode"]}" if config["sslmode"]
conn_str += "&sslcert=#{config["sslcert"]}" if config["sslcert"]
conn_str += "&sslkey=#{config["sslkey"]}" if config["sslkey"]
conn_str += "&sslrootcert=#{config["sslrootcert"]}" if config["sslrootcert"]
puts conn_str

puts ""
puts "=== CERTIFICATE FILES ==="
puts "SSL Cert exists: #{File.exist?(config["sslcert"]) if config["sslcert"]}"
puts "SSL Key exists: #{File.exist?(config["sslkey"]) if config["sslkey"]}"
puts "SSL CA exists: #{File.exist?(config["sslrootcert"]) if config["sslrootcert"]}"

puts ""
puts "=== CERTIFICATE CN ==="
if config["sslcert"] && File.exist?(config["sslcert"])
  require "openssl"
  cert = OpenSSL::X509::Certificate.new(File.read(config["sslcert"]))
  puts "Certificate CN: #{cert.subject.to_s}"
end

puts ""
puts "=== PASSWORD (first 5 chars for verification) ==="
puts "Password starts with: #{config["password"].to_s[0..4]}..." if config["password"]



