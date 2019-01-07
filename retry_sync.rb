#!/usr/bin/env ruby

require 'octokit'

@client = Octokit::Client.new
p @client
repos = `ssh neon@git.neon.kde.org`.split("\n").collect { |x| x.split.last }

repos.each do |repo|
    next unless repo&.include?('/')
    component, *_, name = repo.split('/')
    gh_repo = "ds9-debian-#{component}/#{name}".freeze

    next unless %w(qt plasma kde-extras).include?(component)

    begin
        status = @client.source_import_progress(gh_repo, accept: 'application/vnd.github.barred-rock-preview')[:status]
        if status == 'error'
            puts "Retrying #{gh_repo}"
            @client.update_source_import(gh_repo, accept: 'application/vnd.github.barred-rock-preview') 
        end
    rescue Octokit::ServiceUnavailable, Octokit::UnprocessableEntity, Octokit::NotFound => e
        case e
        when Octokit::ServiceUnavailable
            retry
        when Octokit::UnprocessableEntity
            puts "Boo: #{gh_repo}"
        when Octokit::NotFound
            next
        end
    end
end
