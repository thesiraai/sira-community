require 'redis'
require 'openssl'

cert_path = '/opt/sira-ai/ssl/redis/sira-community-redis-client.crt'
key_path = '/opt/sira-ai/ssl/redis/sira-community-redis-client.key'
ca_path = '/opt/sira-ai/ssl/ca/ca.crt'

puts '=== Testing Redis TLS Connection ==='
puts ''

# Test with ca_file
config = {
  host: 'redis',
  port: 6380,
  password: 'redis_password',
  db: 0,
  ssl: true,
  ssl_params: {
    cert: OpenSSL::X509::Certificate.new(File.read(cert_path)),
    key: OpenSSL::PKey::RSA.new(File.read(key_path)),
    ca_file: ca_path,
    verify_mode: OpenSSL::SSL::VERIFY_PEER
  }
}

begin
  redis = Redis.new(config)
  result = redis.ping
  puts '[SUCCESS] Connection successful! Response: ' + result.to_s
rescue => e
  puts '[FAILED] Connection failed: ' + e.class.to_s + ': ' + e.message
  puts e.backtrace.first(3).join("\n")
end

