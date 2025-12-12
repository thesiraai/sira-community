require_relative 'config/environment'

env_val = ENV["DISCOURSE_SECRET_KEY_BASE"]
puts "ENV variable present: #{env_val.present?}"
puts "ENV variable length: #{env_val.length if env_val.present?}"

rails_val = Rails.application.secret_key_base
puts "Rails.application.secret_key_base present: #{rails_val.present?}"
puts "Rails.application.secret_key_base length: #{rails_val.length if rails_val.present?}"
puts "Values match: #{env_val == rails_val}"

if rails_val.nil? || rails_val.empty?
  puts ""
  puts "=========================================="
  puts "ROOT CAUSE IDENTIFIED!"
  puts "=========================================="
  puts "Rails.application.secret_key_base is nil/empty!"
  puts "This will cause 500 errors in views that use sessions/CSRF."
  puts ""
  puts "Discourse reads secret_key_base from:"
  puts "  1. DISCOURSE_SECRET_KEY_BASE env var"
  puts "  2. Or from config/secrets.yml / config/credentials.yml"
  puts ""
  puts "Since ENV var is set but Rails doesn't see it,"
  puts "Discourse may not be configured to read from ENV var."
end



