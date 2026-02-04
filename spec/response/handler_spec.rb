# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/response/handler"

RSpec.describe FpQbo::Response::Handler do
  let(:logger) { instance_double(FpQbo::Logger, debug: nil, info: nil, warn: nil, error: nil) }
  let(:handler) { described_class.new(logger: logger) }
  let(:request) { double("Request", to_h: {}) }

  it "returns SuccessResponse for 200" do
    http_response = double("HTTP", code: "200", body: '{"QueryResponse":{}}', to_hash: {})
    resp = handler.handle(http_response, request)
    expect(resp).to be_a(FpQbo::Response::SuccessResponse)
  end

  it "returns ErrorResponse for 400" do
    http_response = double("HTTP", code: "400", body: '{"Fault":{}}', to_hash: {})
    resp = handler.handle(http_response, request)
    expect(resp).to be_a(FpQbo::Response::ErrorResponse)
  end
end
