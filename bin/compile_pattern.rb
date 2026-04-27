#!/usr/bin/env ruby

require_relative "../lib/compiler"

if ARGV.length != 1
  $stderr.puts "usage: ruby bin/compile_pattern.rb PATTERN"
  exit 1
end

puts Regexpinel.compile(ARGV[0]).join(",")
