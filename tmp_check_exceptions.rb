require_relative 'config/environment'

puts '=== Checking Exception Logs ==='
if ActiveRecord::Base.connection.table_exists?(:exception_logs)
  puts 'ExceptionLog table exists'
  count = ExceptionLog.count
  puts "Total exceptions: #{count}"
  if count > 0
    puts "\nRecent exceptions (last 5):"
    ExceptionLog.order(created_at: :desc).limit(5).each do |e|
      puts "\n#{e.created_at}:"
      puts "  Class: #{e.exception_class}"
      puts "  Message: #{e.message[0..300]}"
      if e.backtrace
        puts "  Backtrace (first 10 lines):"
        e.backtrace[0..9].each { |line| puts "    #{line}" }
      end
    end
  else
    puts 'No exceptions in ExceptionLog table'
  end
else
  puts 'ExceptionLog table does not exist'
end

puts "\n=== Testing /finish-installation with detailed error ==="
begin
  require 'rack/test'
  app = Rails.application
  # Enable detailed error pages
  Rails.application.config.consider_all_requests_local = true
  env = Rack::MockRequest.env_for('/finish-installation')
  status, headers, body = app.call(env)
  puts "Status: #{status}"
  body_str = body.to_a.join
  if status == 500
    puts "Error response body (first 3000 chars):"
    puts body_str[0..3000]
  end
rescue => e
  puts "EXCEPTION during test: #{e.class}: #{e.message}"
  puts e.backtrace.first(15).join("\n")
end



