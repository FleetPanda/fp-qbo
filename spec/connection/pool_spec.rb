# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/connection/pool"

RSpec.describe FpQbo::Connection::Pool do
  let(:pool) { described_class.new(size: 1, timeout: 0.1) }

  it "yields a connection" do
    expect { |b| pool.with_connection("realm", &b) }.to yield_control
  end
end
