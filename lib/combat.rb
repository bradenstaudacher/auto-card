# Pure-Ruby deterministic combat engine. No Rails dependencies — loadable and
# testable in isolation. Require this file to pull in the whole engine.
require_relative "combat/prng"
require_relative "combat/type_chart"
require_relative "combat/timeline_event"
require_relative "combat/grid"
require_relative "combat/unit"
require_relative "combat/damage"
require_relative "combat/status_effects"
require_relative "combat/targeting"
require_relative "combat/movement"
require_relative "combat/abilities/base"
require_relative "combat/abilities/vampiric_drain"
require_relative "combat/abilities/cleave"
require_relative "combat/abilities/hex_bolt"
require_relative "combat/abilities/holy_flare"
require_relative "combat/abilities/shield_pulse"
require_relative "combat/abilities/dawnbreak"
require_relative "combat/abilities/soul_crush"
require_relative "combat/abilities/registry"
require_relative "combat/battle_state"
require_relative "combat/simulator"

module Combat
end
