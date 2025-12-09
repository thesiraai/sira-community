#!/usr/bin/env ruby
# PostgreSQL Connection POC
# Tests different PostgreSQL connection configurations to identify the working setup
# Similar to Redis TLS POC - isolates the issue before applying to application

require 'pg'
require 'openssl'

# Configuration from infrastructure team guidance
HOST = 'postgres-community'
PORT = 5432
DATABASE = 'sira_community'
USERNAME = 'sira_community_user'
PASSWORD = 'community_app_password_2025'

# Certificate paths (as mounted in container)
CERT_DIR = '/opt/sira-ai/ssl/postgres-community'
CA_CERT = '/opt/sira-ai/ssl/ca/ca.crt'
CLIENT_CERT = "#{CERT_DIR}/sira-community-postgres-client.crt"
CLIENT_KEY = "#{CERT_DIR}/sira-community-postgres-client.key"

puts "=" * 80
puts "PostgreSQL Connection POC"
puts "=" * 80
puts ""
puts "Configuration:"
puts "  Host: #{HOST}"
puts "  Port: #{PORT}"
puts "  Database: #{DATABASE}"
puts "  Username: #{USERNAME}"
puts "  Password: #{PASSWORD[0..5]}..."
puts ""
puts "Certificates:"
puts "  CA: #{CA_CERT} (#{File.exist?(CA_CERT) ? 'EXISTS' : 'MISSING'})"
puts "  Client Cert: #{CLIENT_CERT} (#{File.exist?(CLIENT_CERT) ? 'EXISTS' : 'MISSING'})"
puts "  Client Key: #{CLIENT_KEY} (#{File.exist?(CLIENT_KEY) ? 'EXISTS' : 'MISSING'})"
puts ""

# Test 1: Basic connection without SSL
puts "-" * 80
puts "TEST 1: Basic connection (no SSL)"
puts "-" * 80
begin
  conn = PG.connect(
    host: HOST,
    port: PORT,
    dbname: DATABASE,
    user: USERNAME,
    password: PASSWORD
  )
  result = conn.exec("SELECT version();")
  puts "✅ SUCCESS: Connected without SSL"
  puts "   PostgreSQL version: #{result.first['version']}"
  conn.close
rescue => e
  puts "❌ FAILED: #{e.class}: #{e.message}"
end
puts ""

# Test 2: Connection with sslmode=require (no client certs)
puts "-" * 80
puts "TEST 2: Connection with sslmode=require (no client certificates)"
puts "-" * 80
begin
  conn = PG.connect(
    host: HOST,
    port: PORT,
    dbname: DATABASE,
    user: USERNAME,
    password: PASSWORD,
    sslmode: 'require'
  )
  result = conn.exec("SELECT version();")
  puts "✅ SUCCESS: Connected with sslmode=require"
  puts "   PostgreSQL version: #{result.first['version']}"
  conn.close
rescue => e
  puts "❌ FAILED: #{e.class}: #{e.message}"
end
puts ""

# Test 3: Connection with sslmode=require and CA certificate
puts "-" * 80
puts "TEST 3: Connection with sslmode=require + CA certificate"
puts "-" * 80
begin
  conn = PG.connect(
    host: HOST,
    port: PORT,
    dbname: DATABASE,
    user: USERNAME,
    password: PASSWORD,
    sslmode: 'require',
    sslrootcert: CA_CERT
  )
  result = conn.exec("SELECT version();")
  puts "✅ SUCCESS: Connected with sslmode=require + CA cert"
  puts "   PostgreSQL version: #{result.first['version']}"
  conn.close
rescue => e
  puts "❌ FAILED: #{e.class}: #{e.message}"
end
puts ""

# Test 4: Connection with client certificates (mTLS)
puts "-" * 80
puts "TEST 4: Connection with client certificates (mTLS)"
puts "-" * 80
begin
  conn = PG.connect(
    host: HOST,
    port: PORT,
    dbname: DATABASE,
    user: USERNAME,
    password: PASSWORD,
    sslmode: 'require',
    sslrootcert: CA_CERT,
    sslcert: CLIENT_CERT,
    sslkey: CLIENT_KEY
  )
  result = conn.exec("SELECT version();")
  puts "✅ SUCCESS: Connected with mTLS (client certificates)"
  puts "   PostgreSQL version: #{result.first['version']}"
  conn.close
rescue => e
  puts "❌ FAILED: #{e.class}: #{e.message}"
  puts "   Error details: #{e.backtrace.first}" if e.backtrace
end
puts ""

# Test 5: Connection with sslmode=verify-full (strictest)
puts "-" * 80
puts "TEST 5: Connection with sslmode=verify-full + client certificates"
puts "-" * 80
begin
  conn = PG.connect(
    host: HOST,
    port: PORT,
    dbname: DATABASE,
    user: USERNAME,
    password: PASSWORD,
    sslmode: 'verify-full',
    sslrootcert: CA_CERT,
    sslcert: CLIENT_CERT,
    sslkey: CLIENT_KEY
  )
  result = conn.exec("SELECT version();")
  puts "✅ SUCCESS: Connected with sslmode=verify-full + mTLS"
  puts "   PostgreSQL version: #{result.first['version']}"
  conn.close
rescue => e
  puts "❌ FAILED: #{e.class}: #{e.message}"
end
puts ""

# Test 6: Using connection string (like DATABASE_URL)
puts "-" * 80
puts "TEST 6: Connection string with mTLS"
puts "-" * 80
begin
  conn_string = "postgresql://#{USERNAME}:#{PASSWORD}@#{HOST}:#{PORT}/#{DATABASE}?sslmode=require&sslrootcert=#{CA_CERT}&sslcert=#{CLIENT_CERT}&sslkey=#{CLIENT_KEY}"
  conn = PG.connect(conn_string)
  result = conn.exec("SELECT version();")
  puts "✅ SUCCESS: Connected via connection string with mTLS"
  puts "   PostgreSQL version: #{result.first['version']}"
  conn.close
rescue => e
  puts "❌ FAILED: #{e.class}: #{e.message}"
end
puts ""

puts "=" * 80
puts "POC Complete"
puts "=" * 80

