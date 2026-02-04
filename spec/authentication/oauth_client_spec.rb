# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/authentication/oauth_client"

RSpec.describe FpQbo::Authentication::OAuthClient do
  let(:config) do
    double(
      "Config",
      client_id: "cid",
      client_secret: "csecret",
      open_timeout: 5,
      read_timeout: 10
    )
  end
  let(:logger) { double("Logger", info: nil, error: nil) }
  subject { described_class.new(config: config) }

  before do
    allow(FpQbo).to receive(:logger).and_return(logger)
  end

  describe "#authorization_url" do
    it "generates a valid authorization url with all params" do
      url = subject.authorization_url(redirect_uri: "https://cb", state: "abc", scope: "scope1")
      expect(url).to include("client_id=cid")
      expect(url).to include("redirect_uri=https%3A%2F%2Fcb")
      expect(url).to include("scope=scope1")
      expect(url).to include("response_type=code")
      expect(url).to include("state=abc")
    end

    it "generates a url with a random state if not provided" do
      url = subject.authorization_url(redirect_uri: "https://cb")
      expect(url).to include("client_id=cid")
      expect(url).to include("state=")
    end
  end

  describe "#exchange_code_for_token" do
    let(:http_response) { double("HTTPResponse", is_a?: true, body: '{"access_token":"a","refresh_token":"r","expires_in":3600}') }
    let(:realm_id) { "realm" }

    before do
      allow(subject).to receive(:perform_token_exchange).and_return(http_response)
      allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    end

    it "returns a Token on success" do
      token = subject.exchange_code_for_token(code: "code", redirect_uri: "cb", realm_id: realm_id)
      expect(token.access_token).to eq("a")
      expect(token.refresh_token).to eq("r")
      expect(token.realm_id).to eq(realm_id)
      expect(token).to be_a(FpQbo::Authentication::Token)
    end

    it "logs info and error on failure and raises" do
      error_response = double("HTTPResponse", is_a?: false, body: '{"error":"bad"}', message: "Bad Request")
      allow(subject).to receive(:perform_token_exchange).and_return(error_response)
      expect(logger).to receive(:error).with(/Token exchange failed/, hash_including(:error, :realm_id))
      expect {
        subject.exchange_code_for_token(code: "bad", redirect_uri: "cb", realm_id: realm_id)
      }.to raise_error(FpQbo::AuthenticationError)
    end
  end

  describe "private methods" do
    it "returns the default scope" do
      expect(subject.send(:default_scope)).to eq("com.intuit.quickbooks.accounting")
    end

    it "builds a basic auth header" do
      expect(subject.send(:basic_auth_header)).to start_with("Basic ")
      expect(Base64.decode64(subject.send(:basic_auth_header).split.last)).to eq("cid:csecret")
    end

    it "serializes error message from response body" do
      resp = double("HTTPResponse", body: '{"error_description":"desc"}', message: "msg")
      expect(subject.send(:extract_error_message, resp)).to eq("desc")
    end
    it "falls back to message if body is not JSON" do
      resp = double("HTTPResponse", body: "not-json", message: "msg")
      expect(subject.send(:extract_error_message, resp)).to eq("msg")
    end
  end
end
