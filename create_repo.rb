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

  opts.on('-r', '--repo repo1,repo2,repo3', Array, 'Regex to filter out repos') do |v|
    options.repos = v
  end

  opts.on('-g', '--gateway URI', 'open gateway to remote') do |v|
    options.gateway = URI(v)
  end

  opts.on('-d', '--distribution dist', 'distribution') do |v|
    options.distribution = v
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

@repos = []
options.repos.each do |repo|
  x = Aptly::Repository.create("#{repo}-#{options.distribution}",
                                     DefaultDistribution: "netrunner-#{options.distribution}",
                                     DefaultComponent: repo,
                                     Architectures: %w[all amd64 armhf arm64 i386 source])
  @repos << { Name: x.Name, Component: x.DefaultComponent }
end

Aptly.publish(@repos, 'netrunner', Architectures: %w[all amd64 armhf arm64 i386 source])
