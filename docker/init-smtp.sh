#!/bin/bash
# Initialize SMTP if environment variables are set - CONFIG-DRIVEN
# This script runs during Discourse container initialization (runit phase 1)
# It enables SMTP automatically if SMTP environment variables are present

# Only enable SMTP if all required SMTP environment variables are present
if [ -n "$DISCOURSE_SMTP_ADDRESS" ] && [ -n "$DISCOURSE_SMTP_USER_NAME" ] && [ -n "$DISCOURSE_SMTP_PASSWORD" ]; then
  echo "[init-smtp] SMTP environment variables detected - will enable SMTP after Discourse is ready"
  
  # This script runs early in boot, so we'll create a delayed task
  # Discourse will be ready later, so we use a background process
  (
    # Wait for Discourse to be fully initialized (database migrations, etc.)
    sleep 60
    
    # Wait for Rails to be available
    until cd /var/www/discourse && bundle exec rails runner "puts 'Rails ready'" > /dev/null 2>&1; do
      sleep 5
    done
    
    # Enable SMTP and set notification_email via Rails runner (CONFIG-DRIVEN)
    cd /var/www/discourse
    bundle exec rails runner "
      # Enable SMTP if env vars are set
      if SiteSetting.enable_smtp == false
        puts '[init-smtp] Enabling SMTP (config-driven: SMTP env vars are set)...'
        SiteSetting.enable_smtp = true
        puts '[init-smtp] ✅ SMTP enabled automatically based on configuration'
      else
        puts '[init-smtp] SMTP already enabled'
      end
      
      # Set notification_email to match SMTP sender (CONFIG-DRIVEN)
      # This ensures emails are sent from an authorized address
      if ENV['DISCOURSE_NOTIFICATION_EMAIL'].present? && SiteSetting.notification_email != ENV['DISCOURSE_NOTIFICATION_EMAIL']
        puts '[init-smtp] Setting notification_email to match SMTP sender (config-driven)...'
        SiteSetting.notification_email = ENV['DISCOURSE_NOTIFICATION_EMAIL']
        puts '[init-smtp] ✅ notification_email set to: ' + SiteSetting.notification_email
      elsif ENV['DISCOURSE_SMTP_USER_NAME'].present? && SiteSetting.notification_email != ENV['DISCOURSE_SMTP_USER_NAME']
        # Fallback: use SMTP user name if notification_email env var not set
        puts '[init-smtp] Setting notification_email to SMTP user (config-driven fallback)...'
        SiteSetting.notification_email = ENV['DISCOURSE_SMTP_USER_NAME']
        puts '[init-smtp] ✅ notification_email set to: ' + SiteSetting.notification_email
      else
        puts '[init-smtp] notification_email already configured correctly'
      end
    " 2>&1 | tee -a /var/www/discourse/log/production.log
  ) &
else
  echo "[init-smtp] SMTP not enabled: Required environment variables not set"
fi
