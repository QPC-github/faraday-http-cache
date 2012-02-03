require 'spec_helper'

describe Faraday::CacheStore::Response do

  describe 'cacheable?' do
    it "the response isn't' cacheable if the response is marked as private" do
      headers  = { 'Cache-Control' => 'private' }
      response = Faraday::CacheStore::Response.new(:response_headers => headers)

      response.should_not be_cacheable
    end

    it "the response isn't' cacheable if it shouldn't be stored" do
      headers  = { 'Cache-Control' => 'no-store' }
      response = Faraday::CacheStore::Response.new(:response_headers => headers)

      response.should_not be_cacheable
    end

    it "the response isn't cacheable when the status code isn't acceptable" do
      headers  = { 'Cache-Control' => 'max-age=400' }
      response = Faraday::CacheStore::Response.new(:status => 503, :response_headers => headers)
      response.should_not be_cacheable
    end

    [200, 203, 300, 301, 302, 404, 410].each do |status|
      it "the response is cacheable if the status code is #{status} and the response is fresh" do
        headers  = { 'Cache-Control' => 'max-age=400' }
        response = Faraday::CacheStore::Response.new(:status => status, :response_headers => headers)

        response.should be_cacheable
      end
    end
  end

  describe 'freshness' do
    it "is fresh if the response still has some time to live" do
      date = 200.seconds.ago.httpdate
      headers = { 'Cache-Control' => 'max-age=400', 'Date' => date }
      response = Faraday::CacheStore::Response.new(:response_headers => headers)

      response.should be_fresh
    end

    it "isn't fresh when the ttl has expired" do
      date = 500.seconds.ago.httpdate
      headers = { 'Cache-Control' => 'max-age=400', 'Date' => date }
      response = Faraday::CacheStore::Response.new(:response_headers => headers)

      response.should_not be_fresh
    end
  end

  it "sets the 'Date' header if isn't present" do
    headers = { 'Date' => nil }
    response = Faraday::CacheStore::Response.new(:response_headers => headers)

    response.date.should be_present
  end

  describe 'max age calculation' do

    it 'uses the shared max age directive when present' do
      headers = { 'Cache-Control' => 's-maxage=200, max-age=0'}
      response = Faraday::CacheStore::Response.new(:response_headers => headers)
      response.max_age.should == 200
    end

    it 'uses the max age directive when present' do
      headers = { 'Cache-Control' => 'max-age=200'}
      response = Faraday::CacheStore::Response.new(:response_headers => headers)
      response.max_age.should == 200
    end

    it "fallsback to the expiration date leftovers" do
      headers = { 'Expires' => (Time.now + 100).httpdate, 'Date' => Time.now.httpdate }
      response = Faraday::CacheStore::Response.new(:response_headers => headers)
      response.max_age.should == 100
    end

    it "returns nil when there's no information to calculate the max age" do
      response = Faraday::CacheStore::Response.new
      response.max_age.should be_nil
    end
  end

  describe 'age calculation' do
    it "uses the 'Age' header if it's present" do
      response = Faraday::CacheStore::Response.new(:response_headers => { 'Age' => '3' })
      response.age.should == 3
    end

    it "calculates the time from the 'Date' header" do
      date = 3.seconds.ago.httpdate
      response = Faraday::CacheStore::Response.new(:response_headers => { 'Date' => date })
      response.age.should == 3
    end

    it "returns 0 if there's no 'Age' or 'Date' header present" do
      response = Faraday::CacheStore::Response.new(:response_headers => {})
      response.age.should == 0
    end
  end

  describe 'time to live calculation' do
    it "returns the time to live based on the max age limit" do
      date = 200.seconds.ago.httpdate
      headers = { 'Cache-Control' => 'max-age=400', 'Date' => date }
      response = Faraday::CacheStore::Response.new(:response_headers => headers)
      response.ttl.should == 200
    end
  end

  describe "response unboxing" do
    subject { described_class.new(:status => 200, :response_headers => {}, :body => 'Hi!') }
    let(:response) { subject.to_response }

    it 'returns a Faraday::Response' do
      response.should be_a Faraday::Response
    end

    it 'merges the status code' do
      response.status.should == 200
    end

    it 'merges the headers' do
      response.headers.should be_a Hash
    end

    it 'merges the body' do
      response.body.should == "Hi!"
    end
  end
end