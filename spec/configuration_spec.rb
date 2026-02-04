# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/configuration"

RSpec.describe FpQbo::Configuration do
  it "has default values" do
    config = described_class.new
    expect(config.environment).to eq(:sandbox)
    expect(config.base_url).to include("sandbox")
    expect(config.timeout).to eq(60)
  end

  it "allows setting attributes" do
    config = described_class.new
    config.client_id = "id"
    expect(config.client_id).to eq("id")
  end
end
