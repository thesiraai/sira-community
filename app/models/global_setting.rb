# frozen_string_literal: true

class GlobalSetting
  def self.register(key, default)
    define_singleton_method(key) { provider.lookup(key, default) }
  end

  VALID_SECRET_KEY = /\A[0-9a-f]{128}\z/
  # this is named SECRET_TOKEN as opposed to SECRET_KEY_BASE
  # for legacy reasons
  REDIS_SECRET_KEY = "SECRET_TOKEN"

  REDIS_VALIDATE_SECONDS = 30

  # In Rails secret_key_base is used to encrypt the cookie store
  # the cookie store contains session data
  # Discourse also uses this secret key to digest user auth tokens
  # This method will
  # - use existing token if already set in ENV or discourse.conf
  # - generate a token on the fly if needed and cache in redis
  # - skips caching generated token to redis if redis is skipped
  # - enforce rules about token format falling back to redis if needed
  def self.safe_secret_key_base
    if @safe_secret_key_base && @token_in_redis &&
         (@token_last_validated + REDIS_VALIDATE_SECONDS) < Time.now
      @token_last_validated = Time.now
      token = Discourse.redis.without_namespace.get(REDIS_SECRET_KEY)
      Discourse.redis.without_namespace.set(REDIS_SECRET_KEY, @safe_secret_key_base) if token.nil?
    end

    @safe_secret_key_base ||=
      begin
        token = secret_key_base
        if token.blank? || token !~ VALID_SECRET_KEY
          if GlobalSetting.skip_redis?
            token = SecureRandom.hex(64)
          else
            @token_in_redis = true
            @token_last_validated = Time.now

            token = Discourse.redis.without_namespace.get(REDIS_SECRET_KEY)
            unless token && token =~ VALID_SECRET_KEY
              token = SecureRandom.hex(64)
              Discourse.redis.without_namespace.set(REDIS_SECRET_KEY, token)
            end
          end
        end
        if secret_key_base.present? && token != secret_key_base
          STDERR.puts "WARNING: DISCOURSE_SECRET_KEY_BASE is invalid, it was re-generated"
        end
        token
      end
  rescue Redis::ReadOnlyError
    @safe_secret_key_base = SecureRandom.hex(64)
  end

  def self.load_defaults
    default_provider =
      FileProvider.from(File.expand_path("../../../config/discourse_defaults.conf", __FILE__))
    default_provider
      .keys
      .concat(@provider.keys)
      .uniq
      .each do |key|
        default = default_provider.lookup(key, nil)

        instance_variable_set("@#{key}_cache", nil)

        define_singleton_method(key) do
          val = instance_variable_get("@#{key}_cache")
          if val.nil?
            val = provider.lookup(key, default)
            val = :missing if val.nil?
            instance_variable_set("@#{key}_cache", val)
          end
          val == :missing ? nil : val
        end
      end
  end

  def self.skip_db=(v)
    @skip_db = v
  end

  def self.skip_db?
    @skip_db
  end

  def self.skip_redis=(v)
    @skip_redis = v
  end

  def self.skip_redis?
    @skip_redis
  end

  # rubocop:disable Lint/BooleanSymbol
  def self.use_s3?
    (
      @use_s3 ||=
        begin
          if s3_bucket && s3_region &&
               (s3_use_iam_profile || (s3_access_key_id && s3_secret_access_key))
            :true
          else
            :false
          end
        end
    ) == :true
  end
  # rubocop:enable Lint/BooleanSymbol

  def self.s3_bucket_name
    @s3_bucket_name ||= s3_bucket.downcase.split("/")[0]
  end

  # for testing
  def self.reset_s3_cache!
    @use_s3 = nil
  end

  def self.cdn_hostnames
    hostnames = []
    hostnames << URI.parse(cdn_url).host if cdn_url.present?
    hostnames << cdn_origin_hostname if cdn_origin_hostname.present?
    hostnames
  end

  def self.database_config(variables_overrides: {})
    variables_overrides = variables_overrides.with_indifferent_access
    hash = { "adapter" => "postgresql" }

    %w[
      pool
      connect_timeout
      socket
      host
      backup_host
      port
      backup_port
      username
      password
      replica_host
      replica_port
    ].each do |s|
      if val = self.public_send("db_#{s}")
        hash[s] = val
      end
    end

    hostnames = [hostname]
    hostnames << backup_hostname if backup_hostname.present?

    hostnames << URI.parse(cdn_url).host if cdn_url.present?
    hostnames << cdn_origin_hostname if cdn_origin_hostname.present?

    hash["host_names"] = hostnames
    hash["database"] = db_name
    hash["prepared_statements"] = !!self.db_prepared_statements
    hash["idle_timeout"] = connection_reaper_age if connection_reaper_age.present?
    hash["reaping_frequency"] = connection_reaper_interval if connection_reaper_interval.present?
    hash["advisory_locks"] = !!self.db_advisory_locks

    db_variables = provider.keys.filter { |k| k.to_s.starts_with? "db_variables_" }
    if db_variables.length > 0
      hash["variables"] = {}
      db_variables.each do |k|
        hash["variables"][k.slice(("db_variables_".length)..)] = self.public_send(k)
      end
    end

    variables_overrides.each do |key, value|
      hash["variables"] ||= {}
      hash["variables"][key.to_s] = value
    end

    # SIRA Infrastructure: PostgreSQL SSL/TLS Configuration (mTLS - REQUIRED)
    # Per infrastructure team: Port 5432 requires mTLS with client certificates
    # Add SSL mode if configured
    if db_sslmode.present?
      hash["sslmode"] = db_sslmode
    end

    # Add SSL certificates if SSL is required
    if db_sslmode.present? && (db_sslmode == 'require' || db_sslmode == 'verify-full' || db_sslmode == 'verify-ca')
      # Get certificate paths from environment variables (set by entrypoint or docker-compose)
      # Priority: Environment variables (set by entrypoint) > discourse.conf (if registered)
      ssl_cert = ENV['POSTGRES_SSL_CERT'] || ENV['POSTGRES_CLIENT_CERT']
      ssl_key = ENV['POSTGRES_SSL_KEY'] || ENV['POSTGRES_CLIENT_KEY']
      ssl_ca = ENV['POSTGRES_SSL_CA'] || ENV['POSTGRES_CA_FILE']

      # Add SSL parameters if certificates are available
      if ssl_cert.present? && File.exist?(ssl_cert)
        hash["sslcert"] = ssl_cert
      end
      if ssl_key.present? && File.exist?(ssl_key)
        hash["sslkey"] = ssl_key
      end
      if ssl_ca.present? && File.exist?(ssl_ca)
        hash["sslrootcert"] = ssl_ca
      end
    end

    { "production" => hash }
  end

  # For testing purposes
  def self.reset_redis_config!
    @config = nil
    @message_bus_config = nil
  end

  def self.get_redis_replica_host
    return redis_replica_host if redis_replica_host.present?
    redis_slave_host if respond_to?(:redis_slave_host) && redis_slave_host.present?
  end

  def self.get_redis_replica_port
    return redis_replica_port if redis_replica_port.present?
    redis_slave_port if respond_to?(:redis_slave_port) && redis_slave_port.present?
  end

  def self.get_message_bus_redis_replica_host
    return message_bus_redis_replica_host if message_bus_redis_replica_host.present?
    if respond_to?(:message_bus_redis_slave_host) && message_bus_redis_slave_host.present?
      message_bus_redis_slave_host
    end
  end

  def self.get_message_bus_redis_replica_port
    return message_bus_redis_replica_port if message_bus_redis_replica_port.present?
    if respond_to?(:message_bus_redis_slave_port) && message_bus_redis_slave_port.present?
      message_bus_redis_slave_port
    end
  end

  def self.redis_config
    @config ||=
      begin
        c = {}
        c[:host] = redis_host if redis_host
        c[:port] = redis_port if redis_port

        if get_redis_replica_host && get_redis_replica_port && defined?(RailsFailover)
          c[:client_implementation] = RailsFailover::Redis::Client
          c[:custom] = {
            replica_host: get_redis_replica_host,
            replica_port: get_redis_replica_port,
          }
        end

        c[:username] = redis_username if redis_username.present?
        c[:password] = redis_password if redis_password.present?
        c[:db] = redis_db if redis_db != 0
        c[:db] = 1 if Rails.env.test?
        c[:id] = nil if redis_skip_client_commands
        c[:ssl] = true if redis_use_ssl

        # SIRA Infrastructure: Redis TLS with client certificates (mTLS)
        # Port 6380 requires mutual TLS with client certificates and CA verification
        # Per APP_TEAM_CONNECTION_GUIDE.md: Port 6380 requires TLS + client certificates
        # Check if SSL is enabled (redis_use_ssl is set in discourse.conf)
        # Note: redis_use_ssl may return string "true" or boolean true
        ssl_enabled = redis_use_ssl == true || redis_use_ssl.to_s.downcase == 'true' ||
                      (respond_to?(:redis_ssl) && (redis_ssl == true || redis_ssl.to_s.downcase == 'true'))
        
        if ssl_enabled
          # Get certificate paths from discourse.conf or environment variables
          # These are configured in discourse.conf but need to be accessed via provider
          cert_path = nil
          key_path = nil
          ca_path = nil

          # Prioritize environment variables (set by entrypoint script for writable certs)
          # These take precedence over discourse.conf to handle read-only volume mounts
          cert_path = ENV['REDIS_SSL_CERT'] || ENV['REDIS_CLIENT_CERT'] || ENV['REDIS_TLS_CERT']
          key_path = ENV['REDIS_SSL_KEY'] || ENV['REDIS_CLIENT_KEY'] || ENV['REDIS_TLS_KEY']
          ca_path = ENV['REDIS_SSL_CA'] || ENV['REDIS_CA_FILE'] || ENV['REDIS_TLS_CA']

          # Fallback to GlobalSetting methods (if registered in discourse.conf)
          if cert_path.blank? && respond_to?(:redis_ssl_cert) && redis_ssl_cert.present?
            cert_path = redis_ssl_cert
          end
          if key_path.blank? && respond_to?(:redis_ssl_key) && redis_ssl_key.present?
            key_path = redis_ssl_key
          end
          if ca_path.blank? && respond_to?(:redis_ssl_ca) && redis_ssl_ca.present?
            ca_path = redis_ssl_ca
          end

          # Add ssl_params if certificates are available
          # redis-rb gem requires OpenSSL objects for cert/key and file path for ca_file
          if cert_path.present? && key_path.present? && File.exist?(cert_path) && File.exist?(key_path)
            begin
              require 'openssl'
              
              # Check file permissions - if not readable, try to read with sudo or copy to temp
              # This handles read-only volume mounts where files are owned by root
              cert_content = nil
              key_content = nil
              
              begin
                cert_content = File.read(cert_path)
                key_content = File.read(key_path)
              rescue Errno::EACCES => e
                # Permission denied - try copying to writable temp location
                temp_cert_path = "/tmp/redis-client-#{Process.pid}-#{Time.now.to_i}.crt"
                temp_key_path = "/tmp/redis-client-#{Process.pid}-#{Time.now.to_i}.key"
                
                # Copy files using system command (runs as root if needed)
                system("cp #{cert_path} #{temp_cert_path} && chmod 644 #{temp_cert_path}") if File.exist?(cert_path)
                system("cp #{key_path} #{temp_key_path} && chmod 600 #{temp_key_path}") if File.exist?(key_path)
                
                if File.exist?(temp_cert_path) && File.exist?(temp_key_path)
                  cert_content = File.read(temp_cert_path)
                  key_content = File.read(temp_key_path)
                  # Clean up temp files after reading
                  File.delete(temp_cert_path) rescue nil
                  File.delete(temp_key_path) rescue nil
                else
                  raise e
                end
              end
              
              c[:ssl_params] = {
                cert: OpenSSL::X509::Certificate.new(cert_content),
                key: OpenSSL::PKey::RSA.new(key_content),
                verify_mode: OpenSSL::SSL::VERIFY_PEER
              }
              # ca_file must be a string path (not OpenSSL object) per redis-rb gem
              if ca_path.present? && File.exist?(ca_path)
                c[:ssl_params][:ca_file] = ca_path
              end
            rescue => e
              # Log error but don't fail - allow connection attempt without client certs
              # This provides graceful degradation if certificates are misconfigured
              if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
                Rails.logger.error "Failed to load Redis TLS certificates: #{e.message}"
              end
              STDERR.puts "WARNING: Redis TLS certificates not loaded: #{e.message}"
            end
          end
        end

        c.freeze
      end
  end

  def self.message_bus_redis_config
    return redis_config unless message_bus_redis_enabled
    @message_bus_config ||=
      begin
        c = {}
        c[:host] = message_bus_redis_host if message_bus_redis_host
        c[:port] = message_bus_redis_port if message_bus_redis_port

        if get_message_bus_redis_replica_host && get_message_bus_redis_replica_port
          c[:client_implementation] = RailsFailover::Redis::Client
          c[:custom] = {
            replica_host: get_message_bus_redis_replica_host,
            replica_port: get_message_bus_redis_replica_port,
          }
        end

        c[:username] = message_bus_redis_username if message_bus_redis_username.present?
        c[:password] = message_bus_redis_password if message_bus_redis_password.present?
        c[:db] = message_bus_redis_db if message_bus_redis_db != 0
        c[:db] = 1 if Rails.env.test?
        c[:id] = nil if message_bus_redis_skip_client_commands
        c[:ssl] = true if redis_use_ssl

        c.freeze
      end
  end

  def self.add_default(name, default)
    define_singleton_method(name) { default } unless self.respond_to? name
  end

  def self.smtp_settings
    if GlobalSetting.smtp_address
      settings = {
        address: GlobalSetting.smtp_address,
        port: GlobalSetting.smtp_port,
        domain: GlobalSetting.smtp_domain,
        user_name: GlobalSetting.smtp_user_name,
        password: GlobalSetting.smtp_password,
        enable_starttls_auto: GlobalSetting.smtp_enable_start_tls,
        open_timeout: GlobalSetting.smtp_open_timeout,
        read_timeout: GlobalSetting.smtp_read_timeout,
      }

      if settings[:password] || settings[:user_name]
        settings[:authentication] = GlobalSetting.smtp_authentication
      end

      settings[
        :openssl_verify_mode
      ] = GlobalSetting.smtp_openssl_verify_mode if GlobalSetting.smtp_openssl_verify_mode

      settings[:tls] = true if GlobalSetting.smtp_force_tls
      settings.compact
      settings
    end
  end

  class BaseProvider
    def self.coerce(setting)
      return setting == "true" if setting == "true" || setting == "false"
      return $1.to_i if setting.to_s.strip =~ /\A([0-9]+)\z/
      setting
    end

    def resolve(current, default)
      BaseProvider.coerce(current.presence || default.presence)
    end
  end

  class FileProvider < BaseProvider
    attr_reader :data
    def self.from(file)
      parse(file) if File.exist?(file)
    end

    def initialize(file)
      @file = file
      @data = {}
    end

    def read
      ERB
        .new(File.read(@file))
        .result()
        .split("\n")
        .each do |line|
          if line =~ /\A\s*([a-z_]+[a-z0-9_]*)\s*=\s*(\"([^\"]*)\"|\'([^\']*)\'|[^#]*)/
            @data[$1.strip.to_sym] = ($4 || $3 || $2).strip
          end
        end
    end

    def lookup(key, default)
      var = @data[key]
      resolve(var, var.nil? ? default : "")
    end

    def keys
      @data.keys
    end

    def self.parse(file)
      provider = self.new(file)
      provider.read
      provider
    end

    private_class_method :parse
  end

  class EnvProvider < BaseProvider
    def lookup(key, default)
      var = ENV["DISCOURSE_" + key.to_s.upcase]
      resolve(var, var.nil? ? default : nil)
    end

    def keys
      ENV.keys.select { |k| k =~ /\ADISCOURSE_/ }.map { |k| k[10..-1].downcase.to_sym }
    end
  end

  class BlankProvider < BaseProvider
    def lookup(key, default)
      if key == :redis_port
        return ENV["DISCOURSE_REDIS_PORT"] if ENV["DISCOURSE_REDIS_PORT"]
      end
      default
    end

    def keys
      []
    end
  end

  class << self
    attr_accessor :provider
  end

  def self.configure!(
    path: File.expand_path("../../../config/discourse.conf", __FILE__),
    use_blank_provider: Rails.env.test?
  )
    if use_blank_provider
      @provider = BlankProvider.new
    else
      @provider = FileProvider.from(path) || EnvProvider.new
    end
  end

  def self.load_plugins?
    if ENV["LOAD_PLUGINS"] == "1"
      true
    elsif ENV["LOAD_PLUGINS"] == "0"
      false
    elsif Rails.env.test?
      false
    else
      true
    end
  end
end
