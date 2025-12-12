require_relative 'config/environment'

puts "=== STEP 1: Get Actual Exception ==="
if ActiveRecord::Base.connection.table_exists?(:exception_logs)
  count = ExceptionLog.count
  puts "Exception count: #{count}"
  if count > 0
    puts "\nLatest exception:"
    e = ExceptionLog.order(created_at: :desc).first
    puts "  Class: #{e.exception_class}"
    puts "  Message: #{e.message[0..500]}"
    if e.backtrace
      puts "  Backtrace (first 15):"
      e.backtrace[0..14].each { |line| puts "    #{line}" }
    end
  else
    puts "No exceptions in ExceptionLog table"
  end
else
  puts "ExceptionLog table does not exist"
end



