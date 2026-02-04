# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/errors"

RSpec.describe FpQbo::Error do
  it "inherits from StandardError" do
    expect(described_class.ancestors).to include(StandardError)
  end
end

RSpec.describe FpQbo::AuthenticationError do
  it "has error_code" do
    err = described_class.new("msg", error_code: "E")
    expect(err.error_code).to eq("E")
  end
end

RSpec.describe FpQbo::ConnectionError do
  it "has original_error" do
    err = described_class.new("msg", original_error: "orig")
    expect(err.original_error).to eq("orig")
  end
end

RSpec.describe FpQbo::APIError do
  it "has response and status_code" do
    err = described_class.new("msg", response: "resp", status_code: 400)
    expect(err.response).to eq("resp")
    expect(err.status_code).to eq(400)
  end
end
