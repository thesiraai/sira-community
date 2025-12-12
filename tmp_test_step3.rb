require_relative 'config/environment'

puts "=== STEP 3: Test Database ==="
puts "Database connected: #{ActiveRecord::Base.connected?}"
begin
  puts "Testing simple query..."
  result = ActiveRecord::Base.connection.execute("SELECT 1")
  puts "Query OK: #{result.first}"
  puts "Testing SiteSetting query..."
  count = SiteSetting.count
  puts "SiteSetting.count: #{count}"
  puts "Testing User query..."
  user_count = User.count
  puts "User.count: #{user_count}"
  puts "All database tests passed"
rescue => e
  puts "DATABASE ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n")
end



