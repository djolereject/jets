# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/blank"

require "thor"

module Jets
  module Command
    extend ActiveSupport::Autoload

    autoload :Behavior
    autoload :Base

    include Behavior

    HELP_MAPPINGS = %w(-h -? --help)

    cattr_accessor :original_cli_command

    class << self
      def hidden_commands # :nodoc:
        @hidden_commands ||= []
      end

      def environment # :nodoc:
        ENV["JETS_ENV"].presence || ENV["RACK_ENV"].presence || "development"
      end

      # Receives a namespace, arguments, and the behavior to invoke the command.
      def invoke(full_namespace, args = [], **config)
        namespace = full_namespace = full_namespace.to_s

        if char = namespace =~ /:(\w+)$/
          command_name, namespace = $1, namespace.slice(0, char)
        else
          command_name = namespace
        end

        command_name, namespace = "help", "help" if command_name.blank? || HELP_MAPPINGS.include?(command_name)
        command_name, namespace, args = "application", "application", ["--help"] if jets_new_with_no_path?(args)
        command_name, namespace = "version", "version" if %w( -v --version ).include?(command_name)

        original_argv = ARGV.dup
        ARGV.replace(args)

        command = find_by_namespace(namespace, command_name)
        if command && command.all_commands[command_name]
          command.perform(full_namespace, command_name, args, config)
        else
          args = ["--describe", full_namespace] if HELP_MAPPINGS.include?(args[0])
          find_by_namespace("rake").perform(full_namespace, args, config)
        end
      ensure
        ARGV.replace(original_argv)
      end

      # Jets finds namespaces similar to Thor, it only adds one rule:
      #
      # Command names must end with "_command.rb". This is required because Jets
      # looks in load paths and loads the command just before it's going to be used.
      #
      #   find_by_namespace :webrat, :integration
      #
      # Will search for the following commands:
      #
      #   "webrat", "webrat:integration", "jets:webrat", "jets:webrat:integration"
      #
      def find_by_namespace(namespace, command_name = nil) # :nodoc:
        lookups = [ namespace ]
        lookups << "#{namespace}:#{command_name}" if command_name
        lookups.concat lookups.map { |lookup| "jets:#{lookup}" }

        lookup(lookups)

        namespaces = subclasses.index_by(&:namespace)
        namespaces[(lookups & namespaces.keys).first]
      end

      # Returns the root of the Jets engine or app running the command.
      def root
        if defined?(ENGINE_ROOT)
          Pathname.new(ENGINE_ROOT)
        elsif defined?(APP_PATH)
          Pathname.new(File.expand_path("../..", APP_PATH))
        end
      end

      def print_commands # :nodoc:
        commands.each { |command| puts("  #{command}") }
      end

      private
        COMMANDS_IN_USAGE = %w(
          generate
          console
          server
          deploy
          logs
          new
        )
        private_constant :COMMANDS_IN_USAGE

        PRO_COMMANDS = %w(
          projects
          stacks
          releases
          rollback
        )

        def jets_new_with_no_path?(args)
          args == ["new"]
        end

        def commands
          lookup!
          visible_commands = (subclasses - hidden_commands).flat_map(&:printing_commands)
          (visible_commands - COMMANDS_IN_USAGE - PRO_COMMANDS).sort
        end

        def command_type # :doc:
          @command_type ||= "command"
        end

        def lookup_paths # :doc:
          @lookup_paths ||= %w( jets/commands commands )
        end

        def file_lookup_paths # :doc:
          @file_lookup_paths ||= [ "{#{lookup_paths.join(',')}}", "**", "*_command.rb" ]
        end
    end
  end
end
