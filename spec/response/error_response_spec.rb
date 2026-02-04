# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/response/error_response"

RSpec.describe FpQbo::Response::ErrorResponse do
  let(:data) { { "Fault" => { "Error" => [{ "Message" => "msg", "code" => "123" }] } } }
  let(:request) { double("Request") }
  subject { described_class.new(data: data, status_code: 400, headers: {}, request: request) }

  it "is always error" do
    expect(subject.success?).to be false
    expect(subject.error?).to be true
  end

  it "extracts error message and codes" do
    expect(subject.error_message).to include("msg")
    expect(subject.error_codes).to include("123")
  end
end
