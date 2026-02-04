# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/client"
require "fp_qbo/authentication/token"
require "fp_qbo/authentication/oauth_manager"
require "fp_qbo/request/builder"
require "fp_qbo/response/handler"
require "fp_qbo/connection/http_executor"

RSpec.describe FpQbo::Client do
  let(:access_token) { "access" }
  let(:refresh_token) { "refresh" }
  let(:realm_id) { "realm" }
  let(:expires_at) { Time.now + 3600 }
  let(:config) { double("Config", auto_refresh_token: true, retry_count: 1) }
  let(:logger) { double("Logger", info: nil, warn: nil) }
  let(:token) { FpQbo::Authentication::Token.new(access_token: access_token, refresh_token: refresh_token, realm_id: realm_id, expires_at: expires_at) }
  let(:oauth_manager) { instance_double(FpQbo::Authentication::OAuthManager, valid?: true, refresh_needed?: false, refresh!: token, token: token) }
  let(:request_builder) { instance_double(FpQbo::Request::Builder, build: double("Request")) }
  let(:response_handler) { instance_double(FpQbo::Response::Handler, handle: double("Response", error?: false, raise_exception!: nil)) }
  let(:http_executor) { instance_double(FpQbo::Connection::HttpExecutor, execute: double("HTTPResponse")) }

  before do
    allow(FpQbo).to receive(:configuration).and_return(config)
    allow(FpQbo).to receive(:logger).and_return(logger)
    allow(FpQbo::Authentication::OAuthManager).to receive(:new).and_return(oauth_manager)
    allow(FpQbo::Request::Builder).to receive(:new).and_return(request_builder)
    allow(FpQbo::Response::Handler).to receive(:new).and_return(response_handler)
    allow(FpQbo::Connection::HttpExecutor).to receive(:new).and_return(http_executor)
  end

  subject do
    described_class.new(access_token: access_token, refresh_token: refresh_token, realm_id: realm_id,
                        expires_at: expires_at, config: config)
  end

  describe "#query" do
    it "builds and executes a query request" do
      expect(request_builder).to receive(:build).with(hash_including(method: :get, endpoint: "query"))
      expect(http_executor).to receive(:execute)
      expect(response_handler).to receive(:handle)
      subject.query(entity: "Customer")
    end
  end

  describe "#find" do
    it "builds and executes a find request" do
      expect(request_builder).to receive(:build).with(hash_including(method: :get, endpoint: "customer/1"))
      subject.find(entity: "Customer", id: 1)
    end
  end

  describe "#create" do
    it "builds and executes a create request" do
      expect(request_builder).to receive(:build).with(hash_including(method: :post, endpoint: "customer"))
      subject.create(entity: "Customer", data: { Name: "Test" })
    end
  end

  describe "#update" do
    it "builds and executes an update request with sparse true" do
      expect(request_builder).to receive(:build).with(hash_including(method: :post, endpoint: "customer"))
      subject.update(entity: "Customer", id: 1, data: { Name: "Test" }, sparse: true)
    end
    it "builds and executes an update request with sparse false" do
      expect(request_builder).to receive(:build).with(hash_including(method: :post, endpoint: "customer"))
      subject.update(entity: "Customer", id: 1, data: { Name: "Test" }, sparse: false)
    end
  end

  describe "#delete" do
    it "builds and executes a delete request" do
      expect(request_builder).to receive(:build).with(hash_including(method: :post, endpoint: "customer",
                                                                     query: { operation: "delete" }))
      subject.delete(entity: "Customer", id: 1, sync_token: 2)
    end
  end

  describe "#refresh_token!" do
    it "refreshes the token and returns new token data" do
      expect(oauth_manager).to receive(:refresh!).and_return(token)
      result = subject.refresh_token!
      expect(result[:access_token]).to eq(access_token)
      expect(result[:refresh_token]).to eq(refresh_token)
      expect(result[:realm_id]).to eq(realm_id)
    end
  end

  describe "#valid_token?" do
    it "returns token validity" do
      expect(subject.valid_token?).to eq(true)
    end
  end

  describe "#token_expires_soon?" do
    it "returns token expiration status" do
      expect(subject.token_expires_soon?).to eq(false)
    end
  end

  describe "#company_info" do
    it "builds and executes a company info request" do
      expect(request_builder).to receive(:build).with(hash_including(method: :get, endpoint: "companyinfo/#{realm_id}"))
      subject.company_info
    end
  end

  describe "#batch" do
    it "builds and executes a batch request" do
      ops = [{ operation: "create", entity: "Customer", data: { Name: "Test" } }]
      expect(request_builder).to receive(:build).with(hash_including(method: :post, endpoint: "batch"))
      subject.batch(ops)
    end
  end

  describe "#build_query_string" do
    it "builds a query string with all params" do
      result = subject.build_query_string("Customer", "Active=true", "Name", 10, 5)
      expect(result).to include("SELECT Name FROM Customer WHERE Active=true STARTPOSITION 6 MAXRESULTS 10")
    end
    it "builds a query string with minimal params" do
      result = subject.build_query_string("Customer", nil, "*", 100, 0)
      expect(result).to include("SELECT * FROM Customer MAXRESULTS 100")
    end
  end

  describe "#ensure_valid_token!" do
    it "does nothing if token is valid" do
      expect { subject.send(:ensure_valid_token!) }.not_to raise_error
    end
    it "raises error if token is invalid and no refresh token" do
      allow(oauth_manager).to receive(:valid?).and_return(false)
      allow(config).to receive(:auto_refresh_token).and_return(false)
      allow(oauth_manager).to receive_message_chain(:token, :refresh_token).and_return(nil)
      expect { subject.send(:ensure_valid_token!) }.to raise_error(FpQbo::TokenExpiredError)
    end
    it "refreshes token if invalid and auto_refresh_token is true" do
      allow(oauth_manager).to receive(:valid?).and_return(false)
      allow(oauth_manager).to receive_message_chain(:token, :refresh_token).and_return("refresh")
      expect(oauth_manager).to receive(:refresh!)
      expect(logger).to receive(:info)
      expect { subject.send(:ensure_valid_token!) }.not_to raise_error
    end
  end

  describe "#execute_request" do
    it "handles successful response" do
      request = double("Request")
      response = double("Response", error?: false, raise_exception!: nil)
      allow(http_executor).to receive(:execute).and_return("http_response")
      allow(response_handler).to receive(:handle).and_return(response)
      expect(subject.send(:execute_request, request)).to eq(response)
    end
    it "raises exception on error response" do
      request = double("Request")
      response = double("Response", error?: true)
      allow(http_executor).to receive(:execute).and_return("http_response")
      allow(response_handler).to receive(:handle).and_return(response)
      expect(response).to receive(:raise_exception!)
      expect(subject.send(:execute_request, request)).to eq(response)
    end
    it "handles RateLimitError and retries if configured" do
      request = double("Request")
      error = FpQbo::RateLimitError.new("Rate limit", retry_after: 1)
      allow(http_executor).to receive(:execute).and_raise(error)
      allow(logger).to receive(:warn)
      allow(config).to receive(:retry_count).and_return(1)
      allow(http_executor).to receive(:execute).and_return("http_response")
      response = double("Response", error?: false, raise_exception!: nil)
      allow(response_handler).to receive(:handle).and_return(response)
      expect(subject.send(:execute_request, request)).to eq(response)
    end
  end
end
