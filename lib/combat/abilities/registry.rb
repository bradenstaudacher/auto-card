module Combat
  module Abilities
    # Maps ability name => shared stateless definition instance. New abilities
    # register here; combat stays data-driven (units reference abilities by name).
    module Registry
      DEFINITIONS = {
        "Vampiric Drain" => VampiricDrain.new,
        "Cleave"         => Cleave.new,
        "Hex Bolt"       => HexBolt.new,
        "Holy Flare"     => HolyFlare.new,
        "Shield Pulse"   => ShieldPulse.new
      }.freeze

      module_function

      def fetch(name)
        DEFINITIONS[name]
      end

      def known?(name)
        DEFINITIONS.key?(name)
      end
    end
  end
end
