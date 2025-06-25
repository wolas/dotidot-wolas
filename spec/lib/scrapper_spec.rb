require 'rails_helper'

RSpec.describe Scrapper do
  subject { described_class.new(url, fields)  }

  let(:url) { 'https://www.alza.cz/aeg-7000-prosteam-lfr73964cc-d7635493.htm' }
  let(:fields) { { price: ".price-box__price", rating_count: ".ratingCount", rating_value: ".ratingValue" } }
  let(:fixture_path) { Rails.root.join('spec', 'fixtures', 'alza.cz.html') }
  let(:fixture_content) { File.read(fixture_path) }

  context "on successful request" do
    before do
      stub_request(:get, url).to_return(status: 200, body: fixture_content, headers: { 'Content-Type' => 'text/html' })
      subject.call
    end

    it "is successful" do
      expect(subject).to be_success
    end

    it "returns the desired fields" do
      fields.each { |name, _| expect(subject.result[name]).not_to be_nil }
    end

    it "scraps the fields for content" do
      result = subject.result
      expect(result[:price]).to eq("")
      expect(result[:rating_count]).to eq("25 hodnocení")
      expect(result[:rating_value]).to eq("4,9")
    end
  end

  context "on request not found" do
    before do
      stub_request(:get, url).to_return(status: 404, body: 'Not Found')
      subject.call
    end

    it "is not successful" do
      expect(subject).not_to be_success
    end

    it "returns error" do
      expect(subject.error).to eq("Request failed with status: 404")
    end
  end

  context 'when an exception occurs' do
    before do
      allow(Net::HTTP).to receive(:get_response).and_raise(Errno::ECONNREFUSED)
      subject.call
    end

    it "is not successful" do
      expect(subject).not_to be_success
    end

    it "returns error" do
      expect(subject.error).to eq("Error fetching URL: Connection refused")
    end
  end
end
