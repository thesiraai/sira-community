require_relative 'config/environment'

# Enable verbose error pages
Rails.application.config.consider_all_requests_local = true

begin
  require 'rack/test'
  app = Rails.application
  env = Rack::MockRequest.env_for('/finish-installation')
  status, headers, body = app.call(env)
  body_str = body.to_a.join
  
  if status == 500
    # Remove all HTML tags to get plain text
    text = body_str.gsub(/<[^>]+>/, "\n").gsub(/\n+/, "\n").strip
    
    # Find the exception section
    if text =~ /(Action Controller: Exception caught.*?)(Request|Response|GET|POST)/m
      exception_section = $1
      puts "=========================================="
      puts "ROOT CAUSE IDENTIFIED"
      puts "=========================================="
      puts exception_section[0..2000]
    else
      # Try to find error message directly
      if text =~ /(undefined method[^\n]{10,200})/i
        puts "=========================================="
        puts "ROOT CAUSE IDENTIFIED"
        puts "=========================================="
        puts "ERROR: #{$1}"
      elsif text =~ /(NoMethodError[^\n]{10,200})/i
        puts "=========================================="
        puts "ROOT CAUSE IDENTIFIED"
        puts "=========================================="
        puts "ERROR: #{$1}"
      elsif text =~ /(NameError[^\n]{10,200})/i
        puts "=========================================="
        puts "ROOT CAUSE IDENTIFIED"
        puts "=========================================="
        puts "ERROR: #{$1}"
      else
        # Output a section that might contain the error
        puts "=========================================="
        puts "FULL ERROR PAGE TEXT (first 3000 chars)"
        puts "=========================================="
        puts text[0..3000]
      end
    end
  else
    puts "Status: #{status} (not 500)"
  end
rescue => e
  puts "EXCEPTION during test: #{e.class}: #{e.message}"
  puts e.backtrace.first(15).join("\n")
end



