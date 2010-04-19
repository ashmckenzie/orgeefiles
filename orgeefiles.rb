#!/usr/bin/env ruby

# Author: Ash McKenzie (ash@ashmckenzie.org)
#
# Simple Ruby script to move files from one location to another based
# on a defined set of rules in config.yml.
#
# Look for NOTE: entries for things to change.

require 'rubygems'
require 'logger'
require 'yaml'
require 'fileutils'
require 'optiflag'
require 'zlib'

module Orgeefiles extend OptiFlagSet

  optional_switch_flag "forreal"
  optional_switch_flag "debug"
  optional_switch_flag "quiet"
  and_process!

  class Orgeefiles

    @log = nil
    @config = nil
    @files = nil
    @default_dest_dir = nil

    def initialize
      @log = Logger.new(STDOUT)

      if ARGV.flags.debug
        @log.level = Logger::DEBUG
      elsif ARGV.flags.quiet
        @log.level = Logger::ERROR
      else
        @log.level = Logger::INFO
      end

      @config = YAML.load_file('config.yml')

      unless File.directory?(@config['source']['dir'])
        raise "'#{@config['source']['dir']}' does not exist."
      end
    end

    def run
      self.get_files
      self.look_for_files_to_move
    end

    protected

    def get_files
      @files = []
      src_dir = @config['source']['dir']
      regex = Regexp.new(@config['source']['regex'], Regexp::IGNORECASE)
      @default_dest_dir = @config['destination']['dir']

      @log.info "Looking for files to move from #{src_dir}"

      Dir["#{src_dir}/**/*"].each do |entry|
        if regex.match(entry)
          @log.debug "Found #{entry}"
          @files << entry
        end
      end
    end

    def look_for_files_to_move

      @files.each do |src_file|

        @config['mappings'].each do |mapping|

          dir = mapping['dir']
          regex = Regexp.new(mapping['regex'], Regexp::IGNORECASE)

          if m = regex.match(src_file)

            if mapping['dest_dir']
              dest_dir = eval '"' + mapping['dest_dir'] + '"'
            else
              dest_dir = eval '"' + @default_dest_dir + '"'
            end

            if ARGV.flags.forreal
              @log.info "Moving #{src_file} to #{dest_dir}"
              self.move_file(src_file, dest_dir)
            else
              @log.info "Would have moved #{src_file} to #{dest_dir}"
            end

          end
        end
      end
    end

    def move_file(src_file, dest_dir)
      raise "Directory '#{dest_dir}' does not exist" unless File.directory?(File.dirname(dest_dir))
      Dir.mkdir(dest_dir) unless File.directory?(dest_dir)
      FileUtils.cp("#{src_file}", "#{dest_dir}/")

      @log.info "Calculating checksum for #{src_file}"
      src_checksum = self.crc32(src_file)

      dest_file = "#{dest_dir}/#{File.basename(src_file)}"
      @log.info "Calculating checksum for #{dest_file}"
      dest_checksum = self.crc32(dest_file)

      if dest_checksum == src_checksum
        @log.info "Checksums match, removing #{src_file}"
        File.delete("#{src_file}")
      else
        raise "MD5's don't match for '#{src_file}' (src=[#{src_checksum}], dest=[#{dest_checksum}])"
      end

      src_checksum = nil
      dest_checksum = nil

    end

    def crc32(file)
      return Zlib::crc32(self.read_file(file))
    end

    def read_file(file)
      contents = ''
      open(file, "r") do |io|
        while (!io.eof)
          readBuf = io.readpartial(1024)
          contents << readBuf
        end
      end
      return contents
    end

  end

end 

o = Orgeefiles::Orgeefiles.new
o.run
