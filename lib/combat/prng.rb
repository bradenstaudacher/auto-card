module Combat
  # Deterministic PRNG. Self-contained LCG (PCG-style constants) so battle
  # results are byte-identical across Ruby versions and platforms, unlike
  # ::Random whose internals carry no cross-version guarantee.
  class Prng
    MASK64 = (1 << 64) - 1
    MULT   = 6364136223846793005
    INCR   = 1442695040888963407

    # Accepts a string or integer seed. Strings are folded into a 64-bit
    # integer with a stable FNV-1a hash so the same seed string always maps
    # to the same stream.
    def initialize(seed)
      @state = (seed.is_a?(Integer) ? seed : fnv1a(seed.to_s)) & MASK64
      # Advance once so a zero seed does not produce a degenerate stream.
      next_u64
    end

    # Uniform integer in 0...n (n > 0).
    def rand_int(n)
      raise ArgumentError, "n must be positive" unless n.positive?
      next_u64 % n
    end

    # Uniform float in [0, 1).
    def rand_float
      next_u64.fdiv(MASK64 + 1)
    end

    # True with probability p (0.0..1.0).
    def chance?(p)
      return false if p <= 0
      return true if p >= 1
      rand_float < p
    end

    private

    def next_u64
      @state = (@state * MULT + INCR) & MASK64
      # xorshift output mixing for better bit dispersion
      x = @state
      x ^= x >> 33
      x = (x * 0xff51afd7ed558ccd) & MASK64
      x ^= x >> 33
      x
    end

    def fnv1a(str)
      hash = 0xcbf29ce484222325
      str.each_byte do |b|
        hash ^= b
        hash = (hash * 0x100000001b3) & MASK64
      end
      hash
    end
  end
end
