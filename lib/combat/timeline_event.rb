module Combat
  # A single deterministic event in the battle timeline. The React client
  # replays an ordered list of these; it never computes combat itself.
  class TimelineEvent
    attr_reader :tick, :type, :data

    def initialize(tick:, type:, **data)
      @tick = tick
      @type = type
      @data = data
    end

    def to_h
      { tick: tick, type: type }.merge(data)
    end
  end
end
