#!/usr/bin/env ruby
require 'pry'
require 'aws-sdk'
require 'set'
def ec2
  @ec2 ||= Aws::EC2::Client.new
end

def find_instances()
  result = ec2.describe_instances(
    filters: [ {name: "instance-lifecycle", values:[ "spot" ]} ]
  )
  instances = Set.new
  result.each do |x|
    x.reservations.each do |r|
      r.instances.each do |i|
          public_ip = i.public_ip_address || "-"
          private_ip = i.private_ip_address || "-"
          name = i.tags.find { |t| t.key == "Name"}.value
          instances << { id: i.instance_id, name: name, ip: private_ip, public_ip: public_ip }
        end
      end
    end
  return instances.to_a
end
ENV['AWS_REGION'] = "ap-southeast-1"

instances = find_instances()
instances.each do |i|
  printf "%-25s | %-14s |%-14s\n", i[:name], i[:ip], i[:public_ip]
end
