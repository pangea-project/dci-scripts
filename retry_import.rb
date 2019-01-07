#!/usr/bin/env ruby
require 'octokit'
require 'concurrent'

Octokit.auto_paginate = true

@client = Octokit::Client.new

@client.org_repos(ARGV[0]).each do |x|
    # status = @client.source_import_progress(x.full_name, accept: 'application/vnd.github.barred-rock-preview')[:status]
    # next if status == 'complete'
    puts "Retrying #{x.full_name}"
    begin
      @client.update_source_import(x.full_name, accept: 'application/vnd.github.barred-rock-preview')
    rescue Octokit::UnprocessableEntity
      warn "Failed to process #{x.full_name}"
      next
    end
end
