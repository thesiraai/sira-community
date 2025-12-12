require_relative 'config/environment'

puts '=== Discourse Initialization Check ==='
puts "Discourse version: #{Discourse::VERSION::STRING}"
puts "Rails env: #{Rails.env}"
puts "Database connected: #{ActiveRecord::Base.connected?}"
puts "Site settings count: #{SiteSetting.count}"
puts "Users count: #{User.count}"
puts "Admin users: #{User.where(admin: true).count}"

puts "\n=== Discourse Configuration ==="
puts "Hostname: #{Discourse.current_hostname}"
puts "Base URL: #{Discourse.base_url}"
puts "Site title: #{SiteSetting.title}"
puts "Contact email: #{SiteSetting.contact_email}"

puts "\n=== Testing Root Route ==="
begin
  require 'rack/test'
  app = Rails.application
  env = Rack::MockRequest.env_for('/')
  status, headers, body = app.call(env)
  puts "Status: #{status}"
  body_str = body.to_a.join
  puts "Body length: #{body_str.length}"
  if body_str.include?('Oops')
    puts 'ERROR: Oops page returned'
    puts "Body preview: #{body_str[0..500]}"
  end
rescue => e
  puts "EXCEPTION: #{e.class}: #{e.message}"
  puts e.backtrace.first(15).join("\n")
end

puts "\n=== Checking Exception Logs ==="
if ActiveRecord::Base.connection.table_exists?(:exception_logs)
  puts 'ExceptionLog table exists'
  count = ExceptionLog.count
  puts "Total exceptions: #{count}"
  if count > 0
    puts "\nRecent exceptions:"
    ExceptionLog.order(created_at: :desc).limit(5).each do |e|
      puts "  #{e.created_at}: #{e.message[0..150]}"
      puts "    Class: #{e.exception_class}"
      puts "    Backtrace: #{e.backtrace[0..3].join(' -> ')}" if e.backtrace
    end
  end
else
  puts 'ExceptionLog table does not exist'
end

puts "\n=== Checking Routes ==="
Rails.application.routes.routes.select { |r| r.path.spec.to_s == '/' }.each do |r|
  puts "Root route: #{r.verb} -> #{r.defaults[:controller]}##{r.defaults[:action]}"
end

puts "\n=== Checking finish_installation_required ==="
begin
  ac = Discourse::ApplicationController.new
  result = ac.send(:finish_installation_required?)
  puts "Finish installation required: #{result}"
rescue => e
  puts "Cannot check: #{e.message}"
end



