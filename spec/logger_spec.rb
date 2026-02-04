# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/logger"

RSpec.describe FpQbo::Logger do
  let(:ruby_logger) { instance_double(::Logger, debug: nil, info: nil, warn: nil, error: nil, fatal: nil) }
  subject { described_class.new(ruby_logger) }

  it "delegates debug/info/warn/error/fatal" do
    expect(ruby_logger).to receive(:debug).with(/debug/)
    subject.debug("debug")
    expect(ruby_logger).to receive(:info).with(/info/)
    subject.info("info")
    expect(ruby_logger).to receive(:warn).with(/warn/)
    subject.warn("warn")
    expect(ruby_logger).to receive(:error).with(/error/)
    subject.error("error")
    expect(ruby_logger).to receive(:fatal).with(/fatal/)
    subject.fatal("fatal")
  end
end
