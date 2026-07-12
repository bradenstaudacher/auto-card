require "spec_helper"

RSpec.describe Combat::Prng do
  it "is deterministic for the same seed" do
    a = described_class.new("seed-123")
    b = described_class.new("seed-123")
    seq_a = Array.new(20) { a.rand_int(1000) }
    seq_b = Array.new(20) { b.rand_int(1000) }
    expect(seq_a).to eq(seq_b)
  end

  it "produces different streams for different seeds" do
    a = Array.new(20) { described_class.new("seed-a").rand_int(1_000_000) }
    b = Array.new(20) { described_class.new("seed-b").rand_int(1_000_000) }
    expect(a).not_to eq(b)
  end

  it "accepts integer seeds and stays in range" do
    prng = described_class.new(42)
    100.times { expect(prng.rand_int(6)).to be_between(0, 5) }
  end

  it "chance? respects boundaries" do
    prng = described_class.new("x")
    expect(prng.chance?(0)).to be(false)
    expect(prng.chance?(1)).to be(true)
  end
end
