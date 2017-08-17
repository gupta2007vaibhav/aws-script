#! /usr/bin/env ruby
require 'pg'
require 'optparse'
require 'pp'

class CheckPostgresReplicationStatus
  
  def initialize(options)
    @options = { :user => "test", :password => "test", :database => nil, :port => 5432, :timeout => 30, :warn => nil, :crit => nil }
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: this.rb [option]"
      opts.on('-u', '--user user', 'User') do |user|
      @options[:user] = user
      end 
      opts.on('-p', '--password password', 'Password') do |password|
       @options[:password] = password
      end 
      opts.on('-d', '--database database', 'Database') do |database|
       @options[:database] = database
      end 
      opts.on('-P', '--port port', 'Port') do |port|
       @options[:port] = port
      end 
      opts.on('-m', '--master master', 'Master') do |master|
       @options[:master] = master
      end 
      opts.on('-s', '--slave slave', 'Slave') do |slave|
       @options[:slave] = slave
      end 
      opts.on('-w', '--warn warn', 'Warn') do |warn|
       @options[:warn] = warn.to_i
      end 
      opts.on('-c', '--crit crit', 'Critical') do |crit|
       @options[:crit] = crit.to_i
      end 
      opts.on('-t', '--timeout timeout', 'Timeout') do |timeout|
       @options[:timeout] = timeout
      end 
      opts.on('--help', 'Display Help') do
        puts opts
        exit
      end 
    end 
    parser.parse!(options)
  end  

  def compute_lag(master, slave, m_segbytes)
    m_segment, m_offset = master.split('/')
    s_segment, s_offset = slave.split('/')
    ((m_segment.hex - s_segment.hex) * m_segbytes) + (m_offset.hex - s_offset.hex)
  end

  def replicate
    conn_master = PG.connect(host: @options[:master],
                             dbname: @options[:database],
                             user: @options[:user],
                             password: @options[:password],
                             port: @options[:port],
                             connect_timeout: @options[:timeout])

    byebug
    master = conn_master.exec('SELECT pg_current_xlog_location()').getvalue(0, 0)
    m_segbytes = conn_master.exec('SHOW wal_segment_size').getvalue(0, 0).sub(/\D+/, '').to_i << 20
    conn_master.close

    conn_slave = PG.connect(host: @options[:slave],
                            dbname: @options[:database],
                            user: @options[:user],
                            password: @options[:password],
                            connect_timeout: @options[:timeout])

    slave = conn_slave.exec('SELECT pg_last_xlog_receive_location()').getvalue(0, 0)
    conn_slave.close

    lag = compute_lag(master, slave, m_segbytes)
    lag_in_mb = (lag.to_f / 1024 / 1024).to_i

    if lag_in_mb >= @options[:crit]
      puts "not in sync critical"
    elsif lag_in_mb >= @options[:warn]
      puts "not in sync warning"
    else
      puts "all gud"
    end
  end
end

def main(options)
    db = CheckPostgresReplicationStatus.new(options)
    db.replicate
end
main(ARGV)
