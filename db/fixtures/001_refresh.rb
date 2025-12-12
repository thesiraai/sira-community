# frozen_string_literal: true

class SeedData::Refresher
  @mutex = Mutex.new

  def self.refresh!
    return if @refreshed

    @mutex.synchronize do
      return if @refreshed
      # Fix any bust caches post initial migration
      # Not that reset_column_information is not thread safe so we have to be careful
      # not to run it concurrently within the same process.
      ActiveRecord::Base.connection.tables.each do |table|
        begin
          table.classify.constantize.reset_column_information
        rescue StandardError
          nil
        end
      end

      @refreshed = true
    end
  end
end

SeedData::Refresher.refresh!
SiteSetting.refresh!

# SIRA Community: Automated Production Setup
# These settings are automatically configured during deployment
# to ensure production-grade setup without manual intervention
# All settings are idempotent (safe to run multiple times)

begin
  # Enable bootstrap mode if no users exist (required for fresh installs)
  # Bootstrap mode allows Discourse to show setup wizard when no admin users exist
  if User.count == 0 && !SiteSetting.bootstrap_mode_enabled?
    SiteSetting.set("bootstrap_mode_enabled", true)
    STDERR.puts "✅ Bootstrap mode enabled (no users found - fresh install)"
  end

  # Set hostname from GlobalSetting or environment variable
  # Priority: DISCOURSE_HOSTNAME env var > discourse.conf (GlobalSetting.hostname) > default
  # Note: hostname is configured via GlobalSetting, not SiteSetting
  hostname = ENV["DISCOURSE_HOSTNAME"] || (GlobalSetting.respond_to?(:hostname) && GlobalSetting.hostname) || "localhost"
  STDERR.puts "✅ Hostname: #{hostname} (configured via GlobalSetting/DISCOURSE_HOSTNAME)"

  # Set site title if not already set
  if SiteSetting.title.blank?
    site_title = ENV["DISCOURSE_SITE_TITLE"] || "SIRA Community"
    SiteSetting.set("title", site_title)
    STDERR.puts "✅ Site title configured: #{site_title}"
  end

  # Set contact email if not already set (required for Discourse)
  if SiteSetting.contact_email.blank?
    contact_email = ENV["DISCOURSE_CONTACT_EMAIL"] || "admin@#{hostname}"
    SiteSetting.set("contact_email", contact_email)
    STDERR.puts "✅ Contact email configured: #{contact_email}"
  end

  # Set notification email if not already set
  if SiteSetting.notification_email.blank?
    notification_email = ENV["DISCOURSE_NOTIFICATION_EMAIL"] || SiteSetting.contact_email || "admin@#{hostname}"
    SiteSetting.set("notification_email", notification_email)
    STDERR.puts "✅ Notification email configured: #{notification_email}"
  end

  # Set site contact username if not already set (required for Discourse)
  if SiteSetting.site_contact_username.blank?
    contact_username = ENV["DISCOURSE_SITE_CONTACT_USERNAME"] || "admin"
    SiteSetting.set("site_contact_username", contact_username)
    STDERR.puts "✅ Site contact username configured: #{contact_username}"
  end
rescue => e
  # Don't fail deployment if setup fails - log and continue
  STDERR.puts "⚠️  WARNING: Automated setup encountered an error: #{e.message}"
  STDERR.puts "   This is non-fatal - application will continue to start"
  STDERR.puts "   Error: #{e.class}: #{e.message}"
end