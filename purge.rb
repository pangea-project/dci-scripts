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

  opts.on('-r', '--repo repo', String, 'Regex to filter out repos') do |v|
    options.repo = v
  end

  opts.on('-p', '--package name', String, 'Package name') do |v|
    options.name = v
  end

  opts.on('-g', '--gateway URI', 'open gateway to remote') do |v|
    options.gateway = URI(v)
  end
end
parser.parse!

if options.gateway
  case options.gateway.scheme
  when 'ssh'
    gateway = Net::SSH::Gateway.new(options.gateway.host, options.gateway.user)
    options.port = gateway.open('localhost', options.gateway.port)
  else
    raise 'Gateway scheme not supported'
  end
end

Faraday.default_connection_options =
  Faraday::ConnectionOptions.new(timeout: 2 * 60 * 60)

Aptly.configure do |config|
  config.host = options.host
  config.port = options.port
end

@repo = Aptly::Repository.get(options.repo)
# next unless options.types.include?(repo.Name)

# Query all relevant packages.
# Any package with source as source.
query = "($Source (#{options.name}))"
# Or the source itself
query += " | (#{options.name} {source})"
packages = @repo.packages(q: query).compact.uniq

puts packages

unless packages&.empty?
  @repo.delete_packages(packages)
end

@repo.published_in.each do |x|
  x.update!(ForceOverwrite: true)
end
