# Since run start now requires a champion-selection step, most specs want a run
# already in preparation with a known roster. This helper starts a single-player
# run and selects a default set that includes the champions specs reference.
module RunHelpers
  DEFAULT_CHAMPION_KEYS = %w[ember_vanguard hollow_reaper argent_truvate].freeze

  def start_prepared_run(user, keys: DEFAULT_CHAMPION_KEYS)
    session = RunOrchestrator.start_single_player(user: user)
    RunOrchestrator.new(session).select_champions(player: session.players.first, champion_keys: keys)
    session.reload
  end
end

RSpec.configure { |c| c.include RunHelpers }
