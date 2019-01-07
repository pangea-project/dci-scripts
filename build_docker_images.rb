#!/usr/bin/env ruby
require 'concurrent'

threads = []
archs = %w(armhf arm64 amd64)

#File.open('sources.list', 'w') do |f|
#  f.write("deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20180315/ testing main contrib non-free\n")
#end

pool =
  Concurrent::ThreadPoolExecutor.new(
    min_threads: 2,
    max_threads: 4,
    max_queue: 512,
    fallback_policy: :caller_runs
  )

archs.each do |arch|
  threads << Concurrent::Promise.execute(executor: pool) do
    puts "Building Image for #{arch}"
    system("sudo qemu-debootstrap --arch=#{arch} testing ./testing-#{arch} http://deb.debian.org/debian")
  end
end

Concurrent::Promise.zip(*threads).wait!

archs.each do |arch|
  system("sudo chroot ./testing-#{arch} apt-get clean")
  system("sudo chroot ./testing-#{arch} apt-get autoclean")
#  system("sudo cp sources.list ./testing-#{arch}/etc/apt/")
end
