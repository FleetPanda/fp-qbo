# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/connection/http_executor"

RSpec.describe FpQbo::Connection::HttpExecutor do
  let(:config) { FpQbo::Configuration.new }
  let(:logger) { instance_double(FpQbo::Logger, debug: nil, info: nil, warn: nil, error: nil) }
  let(:executor) { described_class.new(config: config, logger: logger) }
  let(:request) { double("Request", to_h: {}, method: :get) }

  it "retries on timeout error" do
    allow(executor).to receive(:send_request).and_raise(Timeout::Error).once
    allow(executor).to receive(:send_request).and_return(double("HTTP", code: "200", body: "{}", to_hash: {})).once
    expect(executor.execute(request).code).to eq("200")
  end
end
