require_relative 'config/environment'

# Enable verbose error pages
Rails.application.config.consider_all_requests_local = true

puts "=== Testing /finish-installation with verbose errors ==="
begin
  require 'rack/test'
  app = Rails.application
  env = Rack::MockRequest.env_for('/finish-installation')
  status, headers, body = app.call(env)
  puts "Status: #{status}"
  body_str = body.to_a.join
  puts "Body length: #{body_str.length}"
  
  if status == 500
    puts "\n=== ERROR RESPONSE BODY (first 3000 chars) ==="
    puts body_str[0..3000]
    
    # Look for exception details in the body
    if body_str.include?("Exception")
      puts "\n=== FOUND EXCEPTION IN RESPONSE ==="
      # Extract exception class and message
      if body_str =~ /<h2[^>]*>([^<]+Exception[^<]*)<\/h2>/
        puts "Exception Class: #{$1}"
      end
      if body_str =~ /<p[^>]*>([^<]{50,200})<\/p>/
        puts "Exception Message: #{$1}"
      end
    end
  else
    puts "Status is #{status}, not 500"
  end
rescue => e
  puts "EXCEPTION during test: #{e.class}: #{e.message}"
  puts e.backtrace.first(15).join("\n")
end



