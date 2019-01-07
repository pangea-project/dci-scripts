#!/usr/bin/env ruby

require 'aptly'
require 'optparse'
require 'ostruct'
require 'uri'
require 'net/ssh/gateway'
require 'logger'
require 'logger/colors'
require 'html/table'
include HTML


options = OpenStruct.new
options.repos = nil
options.all = false
options.host = 'localhost'
options.port = '8080'
options.distribution = nil

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} [options] --repo yolo"

  opts.on('-g', '--gateway URI', 'open gateway to remote') do |v|
    options.gateway = URI(v)
  end

  opts.on('-d', '--distribution DIST', 'Override distribution in released repository') do |v|
    options.distribution = v
  end
end
parser.parse!

raise parser.help if options.distribution.nil?

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

Faraday.default_connection_options =
  Faraday::ConnectionOptions.new(timeout: 2 * 60 * 60)

@log = Logger.new(STDOUT).tap do |l|
  l.progname = 'snapshotter'
  l.level = Logger::INFO
end

@html = ''

@repos = Aptly::PublishedRepository.list.select { |x| x if x.Distribution.include? options.distribution }
@repos.each do |repo|
  @log.info "Getting #{repo}"
  source = repo.Sources[0]
  @table = HTML::Table.new do
    header source.Name
  end
  packages = source.packages(q: '$Architecture (= source)')
  packages.each do |package|
    _, source, version = package.split
    @table.push Table::Row.new { |r|
      r.align = 'right'
      r.content = [source, version]
    }
  end

  @html += @table.html + '<br>'
end

File.write('packages.html', @html)
