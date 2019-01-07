#!/usr/bin/env ruby

require 'octokit'
require 'concurrent'

Octokit.auto_paginate = true

@client = Octokit::Client.new
@threads = []
repos = `ssh neon@git.neon.kde.org`.split("\n").collect { |x| x.split.last }

def new_or_update(name, component, repo)
    retry_count = 0
    gh_repo = "ds9-debian-#{component}/#{name}".freeze
    begin
        if @client.repository?(gh_repo)
            begin
                puts "Updating import for #{name} at ds9-debian-#{repo}"
                @client.update_source_import(gh_repo, accept: 'application/vnd.github.barred-rock-preview')
                status = 'running'
                until %w[complete error].include?(status) do
                    sleep 5
                    status = @client.source_import_progress(gh_repo, accept: 'application/vnd.github.barred-rock-preview').status
                end
                raise "Error importing #{gh_repo}" if status == 'error'
            rescue
                retry_count += 1
                if retry_count <= 10
                    retry
                else
                    puts "Boo #{gh_repo}"
                end
            end
        else
            puts "Creating import for #{name} at ds9-debian-#{repo}"
            @client.create_repository(name, organization: "ds9-debian-#{component}") 
            sleep 1 until @client.repository?(gh_repo)
            @client.start_source_import(gh_repo, "git://anongit.neon.kde.org/#{repo}", accept: 'application/vnd.github.barred-rock-preview')
        end
    rescue Octokit::ServiceUnavailable, Octokit::UnprocessableEntity, Faraday::ConnectionFailed, Octokit::NotFound => e
        case e
        when Octokit::ServiceUnavailable, Faraday::ConnectionFailed
            retry
        when Octokit::UnprocessableEntity, Octokit::NotFound
            puts "Boo: #{gh_repo}"
        end
    end
end

pool =
  Concurrent::ThreadPoolExecutor.new(
    min_threads: 2,
    max_threads: 2,
    max_queue: 512,
    fallback_policy: :caller_runs
  )

repos.each do |repo|
    next unless repo&.include?('/')
    component, *_, name = repo.split('/')

    next if %w[calamares-settings-debian kobby qt-simulator].include?(name)
    next unless ARGV.include?(component)
    next unless name.include?('kholidays')
    @threads << Concurrent::Promise.execute(executor: pool) do
        new_or_update(name, component, repo)
    end
end

@threads.collect(&:value!)
