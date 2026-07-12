# The combat engine (lib/combat) is a pure-Ruby library that manages its own
# requires and must NOT be autoloaded by Zeitwerk (its combat.rb uses
# require_relative so it can run in isolation under RSpec). Load it once at boot.
require Rails.root.join("lib", "combat")
