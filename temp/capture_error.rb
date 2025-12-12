require_relative '../config/environment'

begin
  app = ActionDispatch::Integration::Session.new(Rails.application)
  app.get '/'
  puts "Status: #{app.response.status}"
  if app.response.status != 200
    puts "\nResponse body (first 1000 chars):"
    puts app.response.body[0..1000]
  end
rescue => e
  puts "\nEXCEPTION: #{e.class}"
  puts "MESSAGE: #{e.message}"
  puts "\nBACKTRACE:"
  puts e.backtrace.first(30).join("\n")
end



