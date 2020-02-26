# frozen_string_literal: true

module Bootboot
  class GemfileNextAutoSync < Bundler::Plugin::API
    def setup
      check_bundler_version
      opt_in
    end

    private

    def check_bundler_version
      self.class.hook("before-install-all") do
        next if Bundler::VERSION >= "1.17.0" || !Bootboot.lockfiles.all.exist?

        Bundler.ui.warn(<<-EOM.gsub(/\s+/, " "))
          Bootboot can't automatically update the Gemfile_next.lock because you are running
          an older version of Bundler.

          Update Bundler to 1.17.0 to discard this warning.
        EOM
      end
    end

    def opt_in
      self.class.hook('before-install-all') do
        @previous_lock = Bundler.default_lockfile.read if Bundler.default_lockfile.exist?
      end

      self.class.hook("after-install-all") do
        current_definition = Bundler.definition

        next if nothing_changed?(current_definition) ||
                ENV['BOOTBOOT_UPDATING_ALTERNATE_LOCKFILE']

        update!(current_definition)
      end
    end

    def nothing_changed?(current_definition)
      @previous_lock && current_definition.to_lock == @previous_lock
    end

    def update!(current_definition)
      # cache this before we start mucking around
      default_lockfile = Bundler.default_lockfile
      Bootboot.lockfiles.each do |lock|
        next if lock.to_s == default_lockfile.to_s
        next unless lock.exist?

        Bundler.ui.confirm("Updating #{lock}")
        ENV['BOOTBOOT_LOCKFILE'] = lock.to_s
        ENV['BOOTBOOT_UPDATING_ALTERNATE_LOCKFILE'] = '1'

        unlock = current_definition.instance_variable_get(:@unlock)
        definition = Bundler::Definition.build(Bundler.default_gemfile, lock, unlock)
        definition.resolve_remotely!
        definition.lock(lock)
      end
    ensure
      ENV.delete('BOOTBOOT_LOCKFILE')
      ENV.delete('BOOTBOOT_UPDATING_ALTERNATE_LOCKFILE')
    end
  end
end
