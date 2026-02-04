# frozen_string_literal: true

require "spec_helper"
require "fp_qbo/authentication/oauth_manager"

RSpec.describe FpQbo::Authentication::OAuthManager do
  let(:token) { instance_double(FpQbo::Authentication::Token, valid?: true, expired?: false, expires_soon?: false, refresh_token: "refresh", realm_id: "123") }
  subject { described_class.new(token) }

  it "returns valid? from token" do
    expect(subject.valid?).to eq(true)
  end

  it "returns refresh_needed? based on token" do
    allow(token).to receive(:expired?).and_return(true)
    expect(subject.refresh_needed?).to eq(true)
  end

  it "raises error if no refresh_token on refresh!" do
    allow(token).to receive(:refresh_token).and_return(nil)
    expect { subject.refresh! }.to raise_error(FpQbo::AuthenticationError)
  end
end
