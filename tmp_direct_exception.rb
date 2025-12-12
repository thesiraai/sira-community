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
    # Save to file first
    File.write('/tmp/error_full.html', body_str)
    
    # Extract text content by removing HTML tags
    text = body_str.gsub(/<script[^>]*>.*?<\/script>/mi, '')
                   .gsub(/<style[^>]*>.*?<\/style>/mi, '')
                   .gsub(/<[^>]+>/, ' ')
                   .gsub(/\s+/, ' ')
                   .strip
    
    puts "=========================================="
    puts "ROOT CAUSE IDENTIFIED"
    puts "=========================================="
    
    # Find exception class
    if text =~ /(Action Controller: Exception caught)/
      puts "Error Type: #{$1}"
    end
    
    # Find exception message - look for common patterns
    if text =~ /(undefined method [`']([^`']+)['`] for [^\n]{10,200})/i
      puts "\nEXCEPTION: #{$1}"
      puts "Missing Method: #{$2}"
    elsif text =~ /(NoMethodError[:\s]+[^\n]{20,200})/i
      puts "\nEXCEPTION: #{$1}"
    elsif text =~ /(NameError[:\s]+[^\n]{20,200})/i
      puts "\nEXCEPTION: #{$1}"
    elsif text =~ /(LoadError[:\s]+[^\n]{20,200})/i
      puts "\nEXCEPTION: #{$1}"
    elsif text =~ /(ArgumentError[:\s]+[^\n]{20,200})/i
      puts "\nEXCEPTION: #{$1}"
    end
    
    # Find file and line
    if text =~ /([\/\w]+\.rb:\d+:)/i
      puts "\nLOCATION:"
      text.scan(/([\/\w]+\.rb:\d+:)/i).first(10).each do |match|
        puts "  #{match[0]}"
      end
    end
    
    # Output relevant section
    puts "\n=== RELEVANT ERROR SECTION (chars 5000-8000) ==="
    puts text[5000..8000] if text.length > 5000
    
    puts "\nFull error saved to /tmp/error_full.html"
  else
    puts "Status: #{status} (not 500)"
  end
rescue => e
  puts "EXCEPTION during test: #{e.class}: #{e.message}"
  puts e.backtrace.first(15).join("\n")
end



