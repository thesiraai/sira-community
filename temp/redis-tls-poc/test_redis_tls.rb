# Redis TLS Connection POC
# This script mimics how Discourse connects to Redis with TLS
# Uses the same certificates and configuration as the application

require 'redis'
require 'openssl'

puts "=== Redis TLS Connection POC ==="
puts ""

# Certificate paths (same as in docker-compose)
CERT_PATH = ENV['REDIS_SSL_CERT'] || '/opt/sira-ai/ssl/redis/sira-community-redis-client.crt'
KEY_PATH = ENV['REDIS_SSL_KEY'] || '/opt/sira-ai/ssl/redis/sira-community-redis-client.key'
CA_PATH = ENV['REDIS_SSL_CA'] || '/opt/sira-ai/ssl/ca/ca.crt'

# Redis connection settings (same as discourse.conf)
REDIS_HOST = ENV['REDIS_HOST'] || 'redis'
REDIS_PORT = ENV['REDIS_PORT'] || '6380'
REDIS_PASSWORD = ENV['REDIS_PASSWORD'] || 'redis_password'
REDIS_DB = ENV['REDIS_DB'] || '0'

puts "Configuration:"
puts "  Host: #{REDIS_HOST}"
puts "  Port: #{REDIS_PORT}"
puts "  DB: #{REDIS_DB}"
puts "  Cert: #{CERT_PATH}"
puts "  Key: #{KEY_PATH}"
puts "  CA: #{CA_PATH}"
puts ""

# Check if files exist
unless File.exist?(CERT_PATH)
  puts "ERROR: Certificate file not found: #{CERT_PATH}"
  exit 1
end

unless File.exist?(KEY_PATH)
  puts "ERROR: Key file not found: #{KEY_PATH}"
  exit 1
end

unless File.exist?(CA_PATH)
  puts "ERROR: CA file not found: #{CA_PATH}"
  exit 1
end

puts "[OK] All certificate files exist"
puts ""

# Test 1: Basic config hash (mimicking GlobalSetting.redis_config)
puts "=== Test 1: Basic config with ssl: true ==="
config1 = {
  host: REDIS_HOST,
  port: REDIS_PORT.to_i,
  password: REDIS_PASSWORD,
  db: REDIS_DB.to_i,
  ssl: true
}

puts "Config: #{config1.inspect}"
begin
  redis1 = Redis.new(config1)
  redis1.ping
  puts "[OK] Connection successful with basic ssl: true"
rescue => e
  puts "[FAIL] Connection failed: #{e.class}: #{e.message}"
  puts "  #{e.backtrace.first(3).join("\n  ")}"
end
puts ""

# Test 2: Config with ssl_params (OpenSSL objects)
puts "=== Test 2: Config with ssl_params (OpenSSL objects) ==="
config2 = {
  host: REDIS_HOST,
  port: REDIS_PORT.to_i,
  password: REDIS_PASSWORD,
  db: REDIS_DB.to_i,
  ssl: true,
  ssl_params: {
    cert: OpenSSL::X509::Certificate.new(File.read(CERT_PATH)),
    key: OpenSSL::PKey::RSA.new(File.read(KEY_PATH)),
    verify_mode: OpenSSL::SSL::VERIFY_PEER
  }
}

puts "Config: ssl_params with cert and key (OpenSSL objects)"
begin
  redis2 = Redis.new(config2)
  redis2.ping
  puts "[OK] Connection successful with ssl_params (OpenSSL objects)"
rescue => e
  puts "[FAIL] Connection failed: #{e.class}: #{e.message}"
  puts "  #{e.backtrace.first(3).join("\n  ")}"
end
puts ""

# Test 3: Config with ssl_params + ca_file
puts "=== Test 3: Config with ssl_params + ca_file ==="
config3 = {
  host: REDIS_HOST,
  port: REDIS_PORT.to_i,
  password: REDIS_PASSWORD,
  db: REDIS_DB.to_i,
  ssl: true,
  ssl_params: {
    cert: OpenSSL::X509::Certificate.new(File.read(CERT_PATH)),
    key: OpenSSL::PKey::RSA.new(File.read(KEY_PATH)),
    ca_file: CA_PATH,
    verify_mode: OpenSSL::SSL::VERIFY_PEER
  }
}

puts "Config: ssl_params with cert, key, and ca_file"
begin
  redis3 = Redis.new(config3)
  redis3.ping
  puts "[OK] Connection successful with ssl_params + ca_file"
rescue => e
  puts "[FAIL] Connection failed: #{e.class}: #{e.message}"
  puts "  #{e.backtrace.first(3).join("\n  ")}"
end
puts ""

# Test 4: Config with ssl_params + ca_cert (OpenSSL object)
puts "=== Test 4: Config with ssl_params + ca_cert (OpenSSL object) ==="
config4 = {
  host: REDIS_HOST,
  port: REDIS_PORT.to_i,
  password: REDIS_PASSWORD,
  db: REDIS_DB.to_i,
  ssl: true,
  ssl_params: {
    cert: OpenSSL::X509::Certificate.new(File.read(CERT_PATH)),
    key: OpenSSL::PKey::RSA.new(File.read(KEY_PATH)),
    ca_cert: OpenSSL::X509::Certificate.new(File.read(CA_PATH)),
    verify_mode: OpenSSL::SSL::VERIFY_PEER
  }
}

puts "Config: ssl_params with cert, key, and ca_cert (OpenSSL object)"
begin
  redis4 = Redis.new(config4)
  redis4.ping
  puts "[OK] Connection successful with ssl_params + ca_cert (OpenSSL)"
rescue => e
  puts "[FAIL] Connection failed: #{e.class}: #{e.message}"
  puts "  #{e.backtrace.first(3).join("\n  ")}"
end
puts ""

# Test 5: Using rediss:// URL
puts "=== Test 5: Using rediss:// URL ==="
redis_url = "rediss://:#{REDIS_PASSWORD}@#{REDIS_HOST}:#{REDIS_PORT}/#{REDIS_DB}"
config5 = {
  url: redis_url,
  ssl_params: {
    cert: OpenSSL::X509::Certificate.new(File.read(CERT_PATH)),
    key: OpenSSL::PKey::RSA.new(File.read(KEY_PATH)),
    ca_file: CA_PATH,
    verify_mode: OpenSSL::SSL::VERIFY_PEER
  }
}

puts "Config: rediss:// URL with ssl_params"
begin
  redis5 = Redis.new(config5)
  redis5.ping
  puts "[OK] Connection successful with rediss:// URL"
rescue => e
  puts "[FAIL] Connection failed: #{e.class}: #{e.message}"
  puts "  #{e.backtrace.first(3).join("\n  ")}"
end
puts ""

puts "=== POC Complete ==="

