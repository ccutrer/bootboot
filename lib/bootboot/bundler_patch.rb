# frozen_string_literal: true

require "bootboot/ruby_source"

module DefinitionPatch
  def initialize(wrong_lock, *args)
    lockfile = if ENV['BOOTBOOT_UPDATING_ALTERNATE_LOCKFILE']
      wrong_lock
    else
      Bootboot.current_lockfile
    end

    super(lockfile, *args)
  end
end

module RubyVersionPatch
  def system
    if ENV['BOOTBOOT_UPDATING_ALTERNATE_LOCKFILE']
      # If we're updating the alternate file and the ruby version specified in
      # the Gemfile is different from the Ruby version currently running, we
      # want to write the version specified in `Gemfile` for the current
      # dependency set to the lock file
      Bundler::Definition.build(Bundler.default_gemfile, nil, false).ruby_version || super
    else
      super
    end
  end
end

module DefinitionSourceRequirementsPatch
  def source_requirements
    super.tap do |source_requirements|
      # Bundler has a hard requirement that Ruby should be in the Metadata
      # source, so this replaces Ruby's Metadata source with our custom source
      source = Bootboot::RubySource.new({})
      source_requirements[source.ruby_spec_name] = source
    end
  end
end

module SharedHelpersPatch
  def default_lockfile(call_original: false)
    return super() if call_original
    Bootboot.current_lockfile
  end
end

Bundler::Definition.prepend(DefinitionSourceRequirementsPatch)
Bundler::RubyVersion.singleton_class.prepend(RubyVersionPatch)

Bundler::Dsl.class_eval do
  def enable_dual_booting(lockfile = nil)
    if ENV['BOOTBOOT_LOCKFILE']
      Bootboot.current_lockfile = Pathname(ENV['BOOTBOOT_LOCKFILE'])
    else
      Bootboot.current_lockfile = lockfile || Bootboot.lockfiles.last
    end
    Bundler::Definition.prepend(DefinitionPatch)
    Bundler::SharedHelpers.singleton_class.prepend(SharedHelpersPatch)
  end
end
