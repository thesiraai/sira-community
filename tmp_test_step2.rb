require_relative 'config/environment'

puts "=== STEP 2: Verify SECRET_KEY_BASE ==="
env_val = ENV["DISCOURSE_SECRET_KEY_BASE"]
puts "ENV variable present: #{env_val.present?}"
puts "ENV variable length: #{env_val.length if env_val.present?}"
begin
  discourse_val = Discourse.secret_key_base
  puts "Discourse.secret_key_base present: #{discourse_val.present?}"
  puts "Discourse.secret_key_base length: #{discourse_val.length if discourse_val.present?}"
  puts "Values match: #{env_val == discourse_val}"
rescue => e
  puts "ERROR getting Discourse.secret_key_base: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end



