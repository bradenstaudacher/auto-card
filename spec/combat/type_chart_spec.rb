require "spec_helper"

RSpec.describe Combat::TypeChart do
  it "encodes the full advantage circle at 1.25x" do
    {
      "Holy" => "Occult", "Occult" => "Death", "Death" => "Fury",
      "Fury" => "Law", "Law" => "Holy"
    }.each do |atk, def_|
      expect(described_class.multiplier(atk, def_)).to eq(1.25)
    end
  end

  it "is neutral for non-advantaged matchups" do
    expect(described_class.multiplier("Holy", "Fury")).to eq(1.0)
    expect(described_class.multiplier("Fury", "Fury")).to eq(1.0)
  end

  it "treats nil types as neutral" do
    expect(described_class.multiplier(nil, "Occult")).to eq(1.0)
  end
end
