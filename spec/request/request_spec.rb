# frozen_string_literal: true
require "spec_helper"
require "fp_qbo/request/request"

RSpec.describe FpQbo::Request::Request do
  let(:now) { Time.now }
  let(:request) do
    described_class.new(
      method: :get,
      url: "https://example.com/api",
      headers: { "Authorization" => "Bearer token", "X-Test" => "1" },
      body: "{\"foo\":\"bar\"}",
      metadata: { realm_id: "123", environment: "sandbox" }
    )
  end

  it "initializes with correct attributes" do
    expect(request.method).to eq(:get)
    expect(request.url).to eq("https://example.com/api")
    expect(request.headers["Authorization"]).to eq("Bearer token")
    expect(request.headers["X-Test"]).to eq("1")
    expect(request.body).to eq("{\"foo\":\"bar\"}")
    expect(request.metadata[:realm_id]).to eq("123")
    expect(request.metadata[:environment]).to eq("sandbox")
    expect(request.created_at).to be_a(Time)
  end

  it "returns true for get? if method is :get" do
    expect(request.get?).to be true
  end
  it "returns true for post? if method is :post" do
    req = described_class.new(method: :post, url: "u", headers: {}, body: nil, metadata: {})
    expect(req.post?).to be true
  end
  it "returns true for put? if method is :put" do
    req = described_class.new(method: :put, url: "u", headers: {}, body: nil, metadata: {})
    expect(req.put?).to be true
  end
  it "returns true for delete? if method is :delete" do
    req = described_class.new(method: :delete, url: "u", headers: {}, body: nil, metadata: {})
    expect(req.delete?).to be true
  end

  it "to_h returns a hash with sanitized url and headers" do
    hash = request.to_h
    expect(hash[:method]).to eq(:get)
    expect(hash[:url]).to eq("https://example.com/api")
    expect(hash[:headers]).not_to have_key("Authorization")
    expect(hash[:body_present]).to be true
    expect(hash[:metadata][:realm_id]).to eq("123")
  end

  it "sanitizes url by removing query params" do
    req = described_class.new(method: :get, url: "https://example.com/api?token=secret", headers: {}, body: nil, metadata: {})
    expect(req.send(:sanitize_url)).to eq("https://example.com/api")
  end

  it "sanitizes headers by removing Authorization" do
    expect(request.send(:sanitize_headers)).not_to have_key("Authorization")
  end
end
