# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/retry/strategy"

RSpec.describe FpQbo::Retry::Strategy do
  let(:logger) { instance_double(FpQbo::Logger, warn: nil, error: nil) }

  it "retries on retryable error and succeeds" do
    strategy = described_class.new(max_attempts: 2, base_delay: 0, max_delay: 0)
    count = 0
    result = strategy.execute do
      count += 1
      raise Timeout::Error if count == 1

      :ok
    end
    expect(result).to eq(:ok)
    expect(count).to eq(2)
  end

  it "raises after max attempts" do
    strategy = described_class.new(max_attempts: 2, base_delay: 0, max_delay: 0)
    expect do
      strategy.execute { raise Timeout::Error }
    end.to raise_error(Timeout::Error)
  end
end
