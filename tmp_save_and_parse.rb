require_relative 'config/environment'
require 'nokogiri'

# Enable verbose error pages
Rails.application.config.consider_all_requests_local = true

begin
  require 'rack/test'
  app = Rails.application
  env = Rack::MockRequest.env_for('/finish-installation')
  status, headers, body = app.call(env)
  body_str = body.to_a.join
  
  if status == 500
    # Parse HTML
    doc = Nokogiri::HTML(body_str)
    
    puts "=========================================="
    puts "ROOT CAUSE IDENTIFIED"
    puts "=========================================="
    
    # Find exception class in h2 tags
    h2_tags = doc.css('h2')
    h2_tags.each do |h2|
      text = h2.text.strip
      if text =~ /Exception/i
        puts "EXCEPTION CLASS: #{text}"
      end
    end
    
    # Find exception message
    message_divs = doc.css('.exception-message .message, .message')
    message_divs.each do |div|
      text = div.text.strip
      if text.length > 10 && text.length < 500
        puts "EXCEPTION MESSAGE: #{text}"
      end
    end
    
    # Find backtrace
    pre_tags = doc.css('pre')
    pre_tags.each do |pre|
      text = pre.text.strip
      if text =~ /\.rb:\d+:/ && text.length > 50
        puts "\nBACKTRACE (first 15 lines):"
        text.split("\n").first(15).each { |line| puts "  #{line}" }
        break
      end
    end
    
    # If Nokogiri parsing doesn't work, try regex on raw HTML
    if body_str =~ /<h2[^>]*>([^<]+Exception[^<]*)<\/h2>/i
      puts "\nEXCEPTION CLASS (regex): #{$1.strip}"
    end
    
    if body_str =~ /<div[^>]*class="message"[^>]*>([^<]{20,300})<\/div>/i
      puts "EXCEPTION MESSAGE (regex): #{$1.strip}"
    end
    
  else
    puts "Status: #{status} (not 500)"
  end
rescue LoadError => e
  # Nokogiri not available, use regex
  if status == 500
    puts "=========================================="
    puts "ROOT CAUSE IDENTIFIED (using regex)"
    puts "=========================================="
    
    # Look for exception class
    if body_str =~ /<h2[^>]*>([^<]+Exception[^<]*)<\/h2>/i
      puts "EXCEPTION CLASS: #{$1.strip}"
    end
    
    # Look for error message in various patterns
    patterns = [
      /<div[^>]*class="[^"]*message[^"]*"[^>]*>([^<]{20,300})<\/div>/i,
      /<p[^>]*class="[^"]*message[^"]*"[^>]*>([^<]{20,300})<\/p>/i,
      /undefined method [`']([^`']+)['`]/i,
      /NoMethodError[:\s]+([^\n<]{20,200})/i
    ]
    
    patterns.each do |pattern|
      if body_str =~ pattern
        puts "EXCEPTION DETAILS: #{$1.strip[0..300]}"
        break
      end
    end
    
    # Save to file for manual inspection
    File.write('/tmp/error_response.html', body_str)
    puts "\nFull error response saved to /tmp/error_response.html"
  end
rescue => e
  puts "EXCEPTION during test: #{e.class}: #{e.message}"
  puts e.backtrace.first(15).join("\n")
end



