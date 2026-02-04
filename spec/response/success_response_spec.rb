# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/response/success_response"

RSpec.describe FpQbo::Response::SuccessResponse do
  let(:data) { { "QueryResponse" => { "Customer" => [{ "Id" => "1" }] } } }
  let(:request) { double("Request") }
  subject { described_class.new(data: data, status_code: 200, headers: {}, request: request) }

  it "is always successful" do
    expect(subject.success?).to be true
    expect(subject.error?).to be false
  end

  it "returns entity from QueryResponse" do
    expect(subject.entity).to eq([{ "Id" => "1" }])
  end
end
