# frozen_string_literal: true

# Override Discourse's built-in admin:create task to make it idempotent and non-interactive
# Must clear BEFORE defining namespace to properly override
Rake::Task["admin:create"].clear if Rake::Task.task_defined?("admin:create")

namespace :admin do
  desc "Create or update admin account (idempotent, non-interactive)"
  task create: :environment do
    # Get admin credentials from environment variables with defaults
    admin_email = ENV["ADMIN_EMAIL"] || ENV["COMMUNITY_ADMIN_EMAIL"] || "admin@sira.ai"
    admin_username = ENV["ADMIN_USERNAME"] || ENV["COMMUNITY_ADMIN_USERNAME"] || "admin"
    admin_password = ENV["ADMIN_PASSWORD"] || ENV["COMMUNITY_ADMIN_PASSWORD"]

    # If no password provided, generate one and print it
    # In non-interactive environments (Docker), never prompt for password
    if admin_password.nil? || admin_password.empty?
      require "securerandom"
      admin_password = SecureRandom.hex(16)
      puts "⚠️  WARNING: No ADMIN_PASSWORD provided, generated random password"
      puts "⚠️  IMPORTANT: Save this password securely!"
    end

    # Check if admin user already exists
    # Discourse stores emails in user_emails table, so we check username first
    existing_user = User.find_by_username(admin_username)
    
    # If not found by username, try to find by email using Discourse's method
    if existing_user.nil? && admin_email.present?
      begin
        existing_user = User.find_by_email(admin_email)
      rescue => e
        # Fallback: try via user_emails join if find_by_email fails
        existing_user = User.joins(:user_emails).where(user_emails: { email: admin_email }).first
      end
    end

    if existing_user
      # Update existing user to ensure admin status
      puts "Found existing user: #{existing_user.username}"
      
      # Update admin status if not already admin
      if !existing_user.admin?
        existing_user.admin = true
        existing_user.moderator = true
        existing_user.active = true
        existing_user.approved = true
        
        if existing_user.save(validate: false)
          puts "✓ Updated user to admin: #{existing_user.username}"
        else
          puts "✗ Failed to update user: #{existing_user.errors.full_messages.join(', ')}"
          exit 1
        end
      else
        puts "✓ User already has admin privileges: #{existing_user.username}"
      end

      # Update password if provided via environment variable
      if ENV["ADMIN_PASSWORD"].present? || ENV["COMMUNITY_ADMIN_PASSWORD"].present?
        existing_user.password = admin_password
        existing_user.password_required!
        if existing_user.save(validate: false)
          puts "✓ Password updated for: #{existing_user.username}"
        else
          puts "⚠️  Warning: Failed to update password (user may need to reset via email)"
        end
      end

      puts "\nAdmin account ready:"
      puts "  Email:    #{existing_user.email}"
      puts "  Username: #{existing_user.username}"
      if ENV["ADMIN_PASSWORD"].present? || ENV["COMMUNITY_ADMIN_PASSWORD"].present?
        puts "  Password: [Updated from environment]"
      else
        puts "  Password: [Unchanged - use existing password or reset via email]"
      end
    else
      # Create new admin user
      puts "Creating new admin account..."
      
      user = User.new
      user.username = admin_username
      user.email = admin_email
      user.password = admin_password
      user.password_required!
      user.active = true
      user.approved = true
      user.admin = true
      user.moderator = true

      if user.save(validate: false)
        puts "✓ SUCCESS: Admin account created!"
        puts "\nAdmin account credentials:"
        puts "  Email:    #{user.email}"
        puts "  Username: #{user.username}"
        puts "  Password: #{admin_password}"
        puts "\n⚠️  IMPORTANT: Save this password securely!"
      else
        puts "✗ ERROR: Failed to create admin account"
        puts "  Errors: #{user.errors.full_messages.join(', ')}"
        exit 1
      end
    end
  end

  desc "List all admin users"
  task list: :environment do
    admins = User.where(admin: true).order(:username)
    
    if admins.any?
      puts "Admin users (#{admins.count}):"
      admins.each do |admin|
        puts "  - #{admin.username} (#{admin.email}) - ID: #{admin.id}"
      end
    else
      puts "No admin users found"
    end
  end

  desc "Remove admin privileges from a user"
  task :remove, [:username] => :environment do |_t, args|
    username = args[:username]
    
    if username.nil?
      puts "✗ ERROR: Username required"
      puts "Usage: rake admin:remove[username]"
      exit 1
    end

    user = User.find_by_username(username)
    
    if user.nil?
      puts "✗ ERROR: User not found: #{username}"
      exit 1
    end

    if !user.admin?
      puts "⚠️  User is not an admin: #{username}"
      exit 0
    end

    user.admin = false
    user.moderator = false
    
    if user.save(validate: false)
      puts "✓ Removed admin privileges from: #{username}"
    else
      puts "✗ Failed to remove admin privileges: #{user.errors.full_messages.join(', ')}"
      exit 1
    end
  end
end
