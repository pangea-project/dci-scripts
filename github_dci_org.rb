#!/usr/bin/env ruby
require 'octokit'
Octokit.auto_paginate = true

@client = Octokit::Client.new

repos = Octokit.org_repos(ARGV[0])

repos.each do |repo|
  puts "Creating hook for #{repo[:name]}"
  @client.create_hook("#{ARGV[0]}/#{repo[:name]}", 'jenkinsgit',
                      jenkins_url: 'http://dci.pangea.pub/',
                      events: 'push',
                      active: true)
end
