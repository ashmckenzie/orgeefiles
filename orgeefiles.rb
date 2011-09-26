#!/usr/bin/env ruby

# Author: Ash McKenzie (ash@greenworm.com.au)
#
# Simple Ruby script to move files from one location to another based
# on a defined set of rules in config.yml.
#
# Look for NOTE: entries for things to change.

require "rubygems"
require "bundler/setup"
Bundler.require(:default)

require "logger"
require "yaml"
require "fileutils"
require 'net/http'

include Log4r

module Orgeefiles extend OptiFlagSet

  optional_switch_flag "forreal"
  optional_switch_flag "dontdelete"
  optional_switch_flag "debug"
  optional_switch_flag "quiet"
  and_process!

  class Orgeefiles

    def initialize

      @log = Log4r::Logger.new ''

      @log.outputters = [ 
        Log4r::StdoutOutputter.new('', :formatter => Log4r::PatternFormatter.new(:pattern => "%d %5l: %m"))
      ]

      if ARGV.flags.debug
        @log.level = DEBUG
      elsif ARGV.flags.quiet
        @log.level = ERROR
      else
        @log.level = INFO
      end

      @config = YAML.load_file('config.yml')

      raise "'#{@config['source']['dir']}' does not exist." unless File.directory?(@config['source']['dir'])
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
      @default_dest_dir = @config['default_dest_dir']
      @dirs = @config['dirs']

      @log.debug "Looking for files to move from #{src_dir}"

      Dir["#{src_dir}/**/*"].each do |entry|
        if regex.match(entry)
          @log.debug "Found #{entry}"
          @files << entry
        end
      end
    end

    def look_for_files_to_move
      moved = 0

      @files.each do |src_file|

        @config['mappings'].each do |mapping|

          dir = eval '"' + mapping['dir'] + '"' if mapping['dir']

          regex = Regexp.new(mapping['regex'], Regexp::IGNORECASE)

          if m = regex.match(File.basename(src_file))

            if mapping['dest_dir']
              dest_dir = eval '"' + mapping['dest_dir'] + '"'
            else
              dest_dir = eval '"' + @default_dest_dir + '"'
            end

            dest_dir.chop!

            if ARGV.flags.forreal
              @log.info "Rsync'ing #{src_file} to #{dest_dir}"
              self.move_file(src_file, "#{dest_dir}/")
              moved =+ 1
            else
              @log.info "Would have rsync'd #{src_file} to #{dest_dir}"
            end

          end
        end
      end

      if moved > 0
        Net::HTTP.get URI.parse('http://imac-new.local:32400/library/sections/7/refresh?force=1')
      end
    end

    def move_file(src_file, dest_dir)
      raise "Directory '#{dest_dir}' does not exist" unless File.directory?(File.dirname(dest_dir))

      Dir.mkdir(dest_dir) unless File.directory?(dest_dir)

      cmd = Escape.shell_command(["/usr/bin/env", "rsync", "-ax", "#{src_file}", "#{dest_dir}/"])
      @log.debug "Rsync command '#{cmd}'"
      system(cmd)

      src_file_size = self.get_file_size(src_file)
      @log.debug "Calculated file size for #{src_file} - #{src_file_size}"

      dest_file = "#{dest_dir}/#{File.basename(src_file)}"
      dest_file_size = self.get_file_size(dest_file)
      @log.debug "Calculated file size for #{dest_file} - #{dest_file_size}"

      if dest_file_size == src_file_size
        if ! ARGV.flags.dontdelete
          @log.info "File sizes match, removing #{src_file}"
          File.delete("#{src_file}")
        else
          @log.info "File sizes match, but not removing #{src_file} (--dontdelete specified)"
        end
      else
        raise "File sizes don't match for '#{src_file}' (src=[#{src_file_size}], dest=[#{dest_file_size}])"
      end
    end

    def get_file_size(file)
      size = File.open(file).stat.size
      @log.debug "Size for #{file} - #{size}"
      return size
    end

  end

end 

o = Orgeefiles::Orgeefiles.new
o.run
