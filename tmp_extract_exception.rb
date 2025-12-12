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
    # Extract exception class
    if body_str =~ /<h2[^>]*>([^<]+Exception[^<]*)<\/h2>/i
      puts "EXCEPTION CLASS: #{$1}"
    end
    
    # Extract exception message
    if body_str =~ /<p[^>]*class="message"[^>]*>([^<]+)<\/p>/i
      puts "EXCEPTION MESSAGE: #{$1}"
    end
    
    # Extract backtrace
    if body_str =~ /<pre[^>]*class="backtrace"[^>]*>([^<]+)<\/pre>/i
      puts "BACKTRACE: #{$1}"
    end
    
    # Try to find any error text
    error_sections = body_str.scan(/<div[^>]*class="[^"]*error[^"]*"[^>]*>([^<]{50,300})<\/div>/i)
    if error_sections.any?
      puts "\nERROR SECTIONS FOUND:"
      error_sections.each { |section| puts "  #{section[0][0..200]}" }
    end
    
    # If HTML parsing doesn't work, look for plain text error patterns
    if body_str =~ /(NoMethodError|NameError|LoadError|ArgumentError|RuntimeError)[:\s]+([^\n<]{20,200})/i
      puts "\nFOUND ERROR PATTERN:"
      puts "  Type: #{$1}"
      puts "  Message: #{$2}"
    end
    
    # Output first 2000 chars for manual inspection
    puts "\n=== FIRST 2000 CHARS OF RESPONSE ==="
    puts body_str[0..2000]
  else
    puts "Status: #{status} (not 500)"
  end
rescue => e
  puts "EXCEPTION during test: #{e.class}: #{e.message}"
  puts e.backtrace.first(15).join("\n")
end



