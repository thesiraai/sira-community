require_relative 'config/environment'

puts "=== STEP 4: Test Redis ==="
begin
  puts "Testing Redis ping..."
  result = Discourse.redis.ping
  puts "Redis ping: #{result}"
  puts "Testing Redis set/get..."
  Discourse.redis.set("test_key", "test_value")
  val = Discourse.redis.get("test_key")
  puts "Redis get: #{val}"
  Discourse.redis.del("test_key")
  puts "All Redis tests passed"
rescue => e
  puts "REDIS ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n")
end



