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

  opts.on('-f', '--from name', String, 'From Repository') do |v|
    options.from_repo = v
  end

  opts.on('-t', '--to name', String, 'To Repository') do |v|
    options.to_repo = v
  end

  opts.on('-r', '--regex name', String, 'Regex') do |v|
    options.regex = v
  end

  opts.on('-g', '--gateway URI', 'open gateway to remote') do |v|
    options.gateway = URI(v)
  end
end
parser.parse!

raise parser.help if options.regex.nil? ||
                     options.to_repo.nil? ||
                     options.from_repo.nil?

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

@from = Aptly::Repository.get(options.from_repo)
@to = Aptly::Repository.get(options.to_repo)
@query =
  "$Source (#{options.regex}) | (#{options.regex}, $PackageType (source))"
@packages = @from.packages(q: @query)
@to.add_packages(@packages)
@from.delete_packages(@packages)
puts "Moved #{@packages}"
