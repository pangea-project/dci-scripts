#!/usr/bin/env ruby

require 'octokit'
Octokit.auto_paginate = true

@client = Octokit::Client.new

repos = Octokit.org_repos(ARGV[0])

repos.each do |repo|
  puts "Checking #{repo.full_name}"
  branches = @client.branches(repo.full_name).collect(&:name)
  next unless branches.include?(ARGV[1])
  next unless branches.include?(ARGV[2])
  ref = @client.branch(repo.full_name, ARGV[1])
  @client.delete_ref(repo.full_name, "heads/#{ARGV[2]}")
  @client.create_ref(repo.full_name, "heads/#{ARGV[2]}", ref.commit.sha)
  puts "Done for #{repo.full_name}"
end
