#! /usr/bin/env ruby

require 'pg'
require 'optparse'
require 'pp'
require 'pry'

class PostgresCheck

  def initialize(options)
    @options = { :user => "test", :password => "test", :hostname => nil, :database => nil, :port => 5432, :timeout => 2000}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: this.rb [option]"
      opts.on('-u', '--user user', 'User') do |user|
      @options[:user] = user
      end
      opts.on('-p', '--password password', 'Password') do |password|
       @options[:password] = password
      end
      opts.on('-h', '--hostname hostname', 'Hostname') do |hostname|
       @options[:hostname] = hostname
      end
      opts.on('-d', '--database database', 'Database') do |database|
       @options[:database] = database
      end
      opts.on('-P', '--port port', 'Port') do |port|
       @options[:port] = port
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


  def run
    begin
      con = PG.connect(host: @options[:hostname],
                       dbname: @options[:database],
                       user: @options[:user],
                       password: @options[:password],
                       port: @options[:port],
                       connect_timeout: @options[:timeout])
      res = con.exec('select version();')
      info = res.first
      puts "Server version: #{info}"
      true
    rescue PG::Error => e
      puts "Error message: #{e.error.split("\n").first}"
      false
    ensure
      con.close if con
    end
  end
end

def main(options)
  db = PostgresCheck.new(options)
  db.run
end
main(ARGV)
