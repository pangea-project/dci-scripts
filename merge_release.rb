#!/usr/bin/env ruby
require 'octokit'
require 'concurrent'

Octokit.auto_paginate = true

@client = Octokit::Client.new
@promises = []
@pool =
  Concurrent::ThreadPoolExecutor.new(
    min_threads: 2,
    max_threads: 2,
    max_queue: 522,
    fallback_policy: :caller_runs
  )

def merge_neon_release(repo)
  branches = @client.branches(repo)
  neon_release = branches.select { |x| x.name == ARGV[1] }.first

  if neon_release
    puts "Merging #{ARGV[1]} into #{ARGV[2]} for #{repo}"
    begin
      @client.merge(repo, ARGV[2], neon_release.commit.sha)
    rescue Octokit::Conflict
      puts "MERGE CONFLICT FOR #{repo}"
    end
  else
    puts "Skipping #{repo}"
  end
end

raise "Not enough arguments" if ARGV.count < 3

@client.org_repos(ARGV[0]).each do |x|
  @promises << Concurrent::Promise.execute(executor: @pool) do
  begin
    merge_neon_release(x.full_name)
  rescue Octokit::NotFound
    ref = @client.branch(x.full_name, ARGV[1])
    @client.create_ref(x.full_name, "heads/#{ARGV[2]}", ref.commit.sha)
  end
  end
end

@promises.collect(&:value!)
