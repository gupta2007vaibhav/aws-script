#!/usr/bin/env ruby
require 'pry'
require 'aws-sdk'
require 'set'
def ec2
  @ec2 ||= Aws::EC2::Client.new
end

def group_present? tag
  val = tag.find { |t| t.key == "group"}
  return (!val.nil?)
end

def find_instances(hosts)
  filter = /\A([a-zA-Z]+)/.match(hosts)[1]
  result = ec2.describe_instances(
    filters: [ {name: "tag:Name", values:[ "#{filter}*" ]} ]
  )
  regex = /\A#{hosts}\z/
  instances = Set.new
  result.each do |x|
    x.reservations.each do |r|
      r.instances.each do |i|
        unless group_present? i.tags
          name = i.tags.find { |t| t.key == "Name"}.value
          next if not name =~ regex
          instances << { id: i.instance_id, name: name }
        end
      end
    end
  end
  return instances.to_a
end

def set_name(id, group)
  instance = Aws::EC2::Instance.new(id)
  instance.create_tags(tags: [{key: "group", value: group }])    
end


ENV['AWS_REGION'] = "ap-southeast-1"
hosts = ARGV.shift
group = ARGV.shift
abort "hosts not specified" if hosts.empty?

instances = find_instances(hosts)
puts group
instances.each do |i|
  set_name(i[:id], group)
end
