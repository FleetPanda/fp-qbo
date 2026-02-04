# frozen_string_literal: true
require "spec_helper"
require "fp_qbo/request/builder"

RSpec.describe FpQbo::Request::Builder do
  let(:oauth_manager) { double("OAuthManager", token: double("Token", realm_id: "123"), authorization_header: "Bearer token") }
  let(:config) { double("Config", base_url: "https://example.com", environment: "sandbox") }
  subject { described_class.new(oauth_manager, config: config) }

  describe "#build" do
    it "returns a Request object with correct attributes" do
      request = subject.build(method: :get, endpoint: "foo", query: { a: 1 }, body: { b: 2 }, headers: { "X-Test" => "1" }, minor_version: 4)
      expect(request).to be_a(FpQbo::Request::Request)
      expect(request.method).to eq(:get)
      expect(request.url).to include("foo")
      expect(request.url).to include("minorversion=4")
      expect(request.headers["Authorization"]).to eq("Bearer token")
      expect(request.headers["X-Test"]).to eq("1")
      expect(request.body).to eq("{\"b\":2}")
      expect(request.metadata[:realm_id]).to eq("123")
      expect(request.metadata[:environment]).to eq("sandbox")
    end

    it "serializes string body as-is" do
      request = subject.build(method: :post, endpoint: "bar", body: "raw string")
      expect(request.body).to eq("raw string")
    end

    it "returns nil body if body is nil" do
      request = subject.build(method: :get, endpoint: "baz")
      expect(request.body).to be_nil
    end

    it "merges custom headers with defaults" do
      request = subject.build(method: :get, endpoint: "foo", headers: { "X-Custom" => "abc" })
      expect(request.headers["X-Custom"]).to eq("abc")
      expect(request.headers["Authorization"]).to eq("Bearer token")
    end
  end

  describe "private methods" do
    it "constructs url with query and minor version" do
      url = subject.send(:construct_url, "foo", { a: 1 }, 2)
      expect(url).to include("foo")
      expect(url).to include("a=1")
      expect(url).to include("minorversion=2")
    end

    it "constructs url without query" do
      url = subject.send(:construct_url, "foo", {}, nil)
      expect(url).to include("foo")
      expect(url).not_to include("?")
    end

    it "builds default headers" do
      headers = subject.send(:default_headers)
      expect(headers["Authorization"]).to eq("Bearer token")
      expect(headers["Accept"]).to eq("application/json")
      expect(headers["Content-Type"]).to eq("application/json")
      expect(headers["User-Agent"]).to include("FpQbo/")
    end

    it "serializes body to JSON if hash" do
      json = subject.send(:serialize_body, { foo: "bar" })
      expect(json).to eq("{\"foo\":\"bar\"}")
    end
    it "returns nil if body is nil" do
      expect(subject.send(:serialize_body, nil)).to be_nil
    end
  end
end
