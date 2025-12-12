require_relative 'config/environment'

# Enable verbose error pages to see the actual missing asset
Rails.application.config.consider_all_requests_local = true

begin
  require 'rack/test'
  app = Rails.application
  env = Rack::MockRequest.env_for('/finish-installation')
  status, headers, body = app.call(env)
  body_str = body.to_a.join
  
  if status == 500
    # Extract the missing asset name from the error
    if body_str =~ /MissingAssetError[^<]*([^<]{10,100})/i
      puts "=========================================="
      puts "MISSING ASSET IDENTIFIED"
      puts "=========================================="
      puts "Error: #{$&}"
    end
    
    # Look for asset path in error message
    if body_str =~ /(start-discourse|browser-update|discourse|\.js|\.css)[^<]{0,50}/i
      puts "\nAsset reference found: #{$1}"
    end
    
    # Try to find the actual asset path being requested
    if body_str =~ /asset_path\(['"]([^'"]+)['"]\)/i
      puts "\nAsset path requested: #{$1}"
    end
    
    # Output relevant section for manual inspection
    if body_str =~ /(MissingAssetError.*?)(Request|Response|GET|POST)/m
      puts "\n=== ERROR DETAILS ==="
      puts $1.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip[0..500]
    end
  else
    puts "Status: #{status} (not 500)"
  end
rescue => e
  puts "EXCEPTION during test: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n")
end



