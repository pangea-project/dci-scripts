#!/usr/bin/env ruby
require 'aptly'
require 'optparse'
require 'ostruct'
require 'uri'
require 'net/ssh/gateway'
require 'logger'
require 'logger/colors'

options = OpenStruct.new
options.host = 'localhost'
options.port = '8080'
options.distribution = nil

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} [options] --repo yolo"

  opts.on('-g', '--gateway URI', 'open gateway to remote') do |v|
    options.gateway = URI(v)
  end

  opts.on('-d', '--distribution dist1, dist2, dist3', Array, 'Override distribution in released repository') do |v|
    options.distribution = v
  end
end
parser.parse!

raise "Need a distribution" unless options.distribution

case options.gateway.scheme
when 'ssh'
    gateway = Net::SSH::Gateway.new(options.gateway.host, options.gateway.user)
    options.port = gateway.open('localhost', options.gateway.port)
else
    raise 'Gateway scheme not supported'
end

Aptly.configure do |config|
    config.host = options.host
    config.port = options.port
end
  
Faraday.default_connection_options =
    Faraday::ConnectionOptions.new(timeout: 40 * 60 * 60)
  
@log = Logger.new(STDOUT).tap do |l|
    l.progname = 'snapshotter'
    l.level = Logger::INFO
end

publishedRepositories = Aptly::PublishedRepository.list
snapshots = Aptly::Snapshot.list

options.distribution.each do |dist|
    publishedRepositories.each do |x|
        next unless x.Distribution == dist
        @log.info("Dropping #{x.Distribution} at #{x.Prefix}")
        begin
            x.drop 
        rescue => e
            @log.info("Error dropping #{x.Distribution} at #{x.Prefix} due to #{e}")
        end
    end

    snapshots.each do |x|
        next unless x.Name.include?("_#{dist}_")
        @log.info("Dropping #{x.Name}")
        begin
            x.delete
        rescue => e
            @log.info("Error dropping #{x.Name} due to #{e}")
        end 
    end
end