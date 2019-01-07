#!/usr/bin/env ruby

require 'aptly'
require 'optparse'
require 'ostruct'
require 'uri'
require 'net/ssh/gateway'
require 'date'

options = OpenStruct.new
options.repos = nil
options.all = false
options.host = 'localhost'
options.port = '8080'
options.distribution = nil

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} [options] --repo yolo"

  opts.on('-r', '--repo name', String, 'Regex to filter out repos') do |v|
    options.repo = v
  end

  opts.on('-g', '--gateway URI', 'open gateway to remote') do |v|
    options.gateway = URI(v)
  end
end
parser.parse!

# raise parser.help if options.regex.nil?

if options.gateway
  case options.gateway.scheme
  when 'ssh'
    gateway = Net::SSH::Gateway.new(options.gateway.host, options.gateway.user)
    options.port = gateway.open('localhost', options.gateway.port)
  else
    raise 'Gateway scheme not supported'
  end
end

Aptly.configure do |config|
  config.host = options.host
  config.port = options.port
end

@repos = Aptly::Repository.list.select { |x| x.Name.match?(options.repo) }

@repos.each do |repo|
  repo.published_in.each { |pubd| pubd.drop }
  puts repo.delete
end
