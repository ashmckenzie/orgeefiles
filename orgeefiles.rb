#!/usr/bin/env ruby

# Author: Ash McKenzie (ash@ashmckenzie.org)
#
# Simple Ruby script to move files from one location to another based
# on a defined set of rules in config.yml.
#
# Look for NOTE: entries for things to change.

require 'rubygems'
require 'yaml'
require 'fileutils'
require 'optiflag'

module Orgeefiles extend OptiFlagSet
  optional_switch_flag "forreal"
  and_process!
end 

config = YAML.load_file('config.yml')

src_dir = config['look']['dir']

unless File.directory?(src_dir)
  raise "ERROR: '#{src_dir}' does not exist."
end

regex = Regexp.new(config['look']['regex'], Regexp::IGNORECASE)

puts "- Looking for files to move in #{src_dir}"

files = []

Dir["#{src_dir}/**/*"].each do |entry|
  if regex.match(entry)
    files << entry
  end
end

files.each do |file|
  config['mappings'].each do |mapping|
    dir = mapping['dir']
    regex = Regexp.new(mapping['regex'], Regexp::IGNORECASE)
    if m = regex.match(file)
      dest_dir = "#{dir}/Season #{m[1].to_i}/"    # NOTE: Change this to suit
      puts "+ Moving #{file} to #{dest_dir}"
      if ARGV.flags.forreal
        raise "Directory '#{dest_dir}' does not exist" unless File.directory?(File.dirname(dest_dir))
        Dir.mkdir(dest_dir) unless File.directory?(dest_dir)
        FileUtils.mv("#{file}", "#{dest_dir}/")
      end
    end
  end
end
