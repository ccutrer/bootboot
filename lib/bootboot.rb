# frozen_string_literal: true

require "bootboot/version"
require "bootboot/bundler_patch"

module Bootboot
  autoload :GemfileNextAutoSync, 'bootboot/gemfile_next_auto_sync'
  autoload :Command,             'bootboot/command'

  class << self
    attr_accessor :current_lockfile

    def env_next
      env_prefix + '_NEXT'
    end

    def lockfiles
      add_lockfile("#{Bundler.default_gemfile}_next.lock") unless @lockfiles
      @lockfiles
    end

    def add_lockfile(lockfile)
      @lockfiles ||= [default_lockfile]
      @lockfiles << lockfile unless @lockfiles.include?(lockfile)
    end

    def default_lockfile
      if defined?(SharedHelpersPatch) && Bundler::SharedHelpers.singleton_class < SharedHelpersPatch
        Bundler::SharedHelpers.default_lockfile(call_original: true)
      else
        Bundler.default_lockfile
      end
    end

    private

    def env_prefix
      Bundler.settings['bootboot_env_prefix'] || 'DEPENDENCIES'
    end
  end
end

Bootboot::GemfileNextAutoSync.new.setup
Bootboot::Command.new.setup
