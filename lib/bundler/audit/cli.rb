#
# Copyright (c) 2013-2020 Hal Brodigan (postmodern.mod3 at gmail.com)
#
# bundler-audit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# bundler-audit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with bundler-audit.  If not, see <http://www.gnu.org/licenses/>.
#

require 'bundler/audit/scanner'
require 'bundler/audit/version'
require 'bundler/audit/cli/formats'

require 'thor'
require 'bundler'
require 'bundler/vendored_thor'

module Bundler
  module Audit
    class CLI < ::Thor

      default_task :check
      map '--version' => :version

      desc 'check', 'Checks the Gemfile.lock for insecure dependencies'
      method_option :quiet, :type => :boolean, :aliases => '-q'
      method_option :verbose, :type => :boolean, :aliases => '-v'
      method_option :ignore, :type => :array, :aliases => '-i'
      method_option :update, :type => :boolean, :aliases => '-u'
      method_option :format, :type => :string, :default => 'text'
      method_option :output, :type => :string, :aliases => '-o'
      method_option :file, type: :string

      def check
        begin
          extend Formats.load(options[:format])
        rescue Formats::FormatNotFound
          say "Unknown format: #{options[:format]}", :red
          exit 1
        end

        update if options[:update]

        scanner = if options[:file]
          Scanner.new(Dir.pwd, options[:file])
        else
          Scanner.new
        end
        report  = scanner.report(:ignore => options.ignore)

        output = if options[:output] then File.new(options[:output],'w')
                 else                     $stdout
                 end

        print_report(report,output)

        output.close if options[:output]
      end

      desc 'update', 'Updates the ruby-advisory-db'
      method_option :quiet, :type => :boolean, :aliases => '-q'

      def update
        say("Updating ruby-advisory-db ...") unless options.quiet?

        case Database.update!(quiet: options.quiet?)
        when true
          say("Updated ruby-advisory-db", :green) unless options.quiet?
        when false
          say "Failed updating ruby-advisory-db!", :red
          exit 1
        when nil
          unless Bundler.git_present?
            say "Git is not installed!", :red
            exit 1
          end
          say "Skipping update", :yellow
        end

        unless options.quiet?
          puts "ruby-advisory-db: #{Database.new.size} advisories"
        end
      end

      desc 'version', 'Prints the bundler-audit version'
      def version
        database = Database.new

        puts "#{File.basename($0)} #{VERSION} (advisories: #{database.size})"
      end

      protected

      #
      # @abstract
      #
      def print_report(report)
        raise(NotImplementedError,"#{self.class}##{__method__} not defined")
      end

      def say(message="", color=nil)
        color = nil unless $stdout.tty?
        super(message.to_s, color)
      end

    end
  end
end
