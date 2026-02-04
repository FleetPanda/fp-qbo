# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/authentication/token"

RSpec.describe FpQbo::Authentication::Token do
  let(:access_token) { "access" }
  let(:refresh_token) { "refresh" }
  let(:realm_id) { "realm" }
  let(:expires_at) { Time.now + 3600 }

  it "is valid with access_token and not expired" do
    token = described_class.new(access_token: access_token, refresh_token: refresh_token, realm_id: realm_id,
                                expires_at: expires_at)
    expect(token.valid?).to be true
    expect(token.expired?).to be false
  end

  it "is invalid if access_token is nil" do
    token = described_class.new(access_token: nil, refresh_token: refresh_token, realm_id: realm_id,
                                expires_at: expires_at)
    expect(token.valid?).to be false
  end

  it "is expired if expires_at is in the past" do
    token = described_class.new(access_token: access_token, refresh_token: refresh_token, realm_id: realm_id,
                                expires_at: Time.now - 10)
    expect(token.expired?).to be true
  end

  it "detects expires_soon? correctly" do
    token = described_class.new(access_token: access_token, refresh_token: refresh_token, realm_id: realm_id,
                                expires_at: Time.now + 100)
    expect(token.expires_soon?(150)).to be true
    expect(token.expires_soon?(50)).to be false
  end
end
