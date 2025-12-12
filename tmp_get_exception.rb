require_relative 'config/environment'

if ActiveRecord::Base.connection.table_exists?(:exception_logs)
  e = ExceptionLog.order(created_at: :desc).first
  if e
    puts "Latest Exception:"
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



