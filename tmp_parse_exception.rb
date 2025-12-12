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
    puts "=========================================="
    puts "ROOT CAUSE IDENTIFIED"
    puts "=========================================="
    
    # Extract exception class from <h2> tags
    if body_str =~ /<h2[^>]*>([^<]+Exception[^<]*)<\/h2>/i
      puts "EXCEPTION CLASS: #{$1.strip}"
    end
    
    # Extract exception message
    if body_str =~ /<div[^>]*class="[^"]*message[^"]*"[^>]*>([^<]{20,500})<\/div>/i
      puts "EXCEPTION MESSAGE: #{$1.strip}"
    end
    
    # Try alternative pattern for message
    if body_str =~ /<p[^>]*class="[^"]*message[^"]*"[^>]*>([^<]{20,500})<\/p>/i
      puts "EXCEPTION MESSAGE (alt): #{$1.strip}"
    end
    
    # Extract backtrace - look for <pre> or <code> with backtrace
    if body_str =~ /<pre[^>]*>([^<]{100,1000})<\/pre>/i
      backtrace = $1
      # Get first few lines
      lines = backtrace.split("\n").first(10)
      puts "\nBACKTRACE (first 10 lines):"
      lines.each { |line| puts "  #{line.strip}" }
    end
    
    # Look for specific error patterns in the HTML
    error_patterns = [
      /undefined method [`']([^`']+)['`]/i,
      /uninitialized constant ([A-Z][\w:]+)/i,
      /No such file or directory[:\s]+([^\n<]+)/i,
      /cannot load such file[:\s]+([^\n<]+)/i
    ]
    
    error_patterns.each do |pattern|
      if body_str =~ pattern
        puts "\nFOUND ERROR PATTERN:"
        puts "  Match: #{$&}"
        break
      end
    end
    
    # Output a section that likely contains the error
    if body_str =~ /(<div[^>]*class="[^"]*exception-message[^"]*"[^>]*>.*?<\/div>)/i
      puts "\n=== EXCEPTION MESSAGE SECTION ==="
      puts $1.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip[0..500]
    end
    
  else
    puts "Status: #{status} (not 500)"
  end
rescue => e
  puts "EXCEPTION during test: #{e.class}: #{e.message}"
  puts e.backtrace.first(15).join("\n")
end



