require 'rails_helper'

RSpec.describe DataController, type: :controller do
  describe 'GET #show' do
    let(:url) { 'https://www.example.com' }
    let(:fields) { ActionController::Parameters.new(price: ".price-box__price", rating_count: ".ratingCount", rating_value: ".ratingValue").permit! }
    let(:sorted_fields_string) { fields.to_h.sort.to_s }
    let(:cache_key) { "requests/#{Digest::MD5.hexdigest(url)}/#{Digest::MD5.hexdigest(sorted_fields_string)}" }
    let(:scraper_result) { { price: "", rating_count: "25 hodnocení", rating_value: "4,9" }}
    let(:scraper_error) { nil }
    let(:scraper_success) { true }
    let(:cached_response)  { { result: scraper_result, error: scraper_error, success: scraper_success } }
    let(:scraper) { instance_double(Scrapper, result: scraper_result, error: scraper_error, success?: scraper_success) }

    before do
      allow(Scrapper).to receive(:new).with(url, fields).and_return(scraper)
      allow(scraper).to receive(:call)
    end

    context 'when the request is successful and cache is empty' do
      it 'fetches data, caches it, and returns 200 with result' do
        expect(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 1.hour).and_yield.and_return(cached_response)
        expect(scraper).to receive(:call)

        get :show, params: { url: url, fields: fields }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(scraper_result.stringify_keys)
      end
    end

    context 'when the request is successful and cache is populated' do
      before { Rails.cache.write(cache_key, cached_response) }

      it 'returns cached data without calling Scrapper' do
        expect(scraper).not_to receive(:call)

        get :show, params: { url: url, fields: fields }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(scraper_result.stringify_keys)
      end
    end

    context 'when fields parameters are provided in different order' do
      let(:reordered_fields) { ActionController::Parameters.new(rating_count: ".ratingCount", rating_value: ".ratingValue", price: ".price-box__price").permit! }
      let(:reordered_cache_key) { "requests/#{Digest::MD5.hexdigest(url)}/#{Digest::MD5.hexdigest(reordered_fields.to_h.sort.to_s)}" }

      before do
        expect(reordered_cache_key).to eq(cache_key) # Verify same cache key
        Rails.cache.write(cache_key, cached_response)
      end

      it 'uses the same cache key for reordered fields' do
        expect(scraper).not_to receive(:call)

        get :show, params: { url: url, fields: reordered_fields }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(scraper_result.stringify_keys)
      end
    end

    context 'when the scraper fails' do
      let(:scraper_error) { 'Failed to fetch URL' }
      let(:scraper_success) { false }
      let(:scraper_result) { { error: scraper_error } }

      before do
        allow(scraper).to receive(:result).and_return(scraper_result)
        allow(scraper).to receive(:error).and_return(scraper_error)
        allow(scraper).to receive(:success?).and_return(scraper_success)
      end

      it 'returns 422 with error result' do
        expect(Rails.cache).to receive(:fetch).with(cache_key, expires_in: 1.hour).and_yield.and_return(cached_response)

        get :show, params: { url: url, fields: fields }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq(scraper_result.stringify_keys)
      end
    end

    context 'when different URLs are provided' do
      let(:url2) { 'https://www.test.com' }
      let(:cache_key2) { "requests/#{Digest::MD5.hexdigest(url2)}/#{Digest::MD5.hexdigest(sorted_fields_string)}" }
      let(:scraper_result2) { { header: '.header', description: '.description' } }
      let(:cached_response2) { { result: scraper_result2, error: nil, success: true } }

      before do
        allow(Scrapper).to receive(:new).with(url2, fields).and_return(scraper)
        Rails.cache.write(cache_key, cached_response) # Cache for url1
      end

      it 'uses a different cache key for a different URL' do
        expect(Rails.cache).to receive(:fetch).with(cache_key2, expires_in: 1.hour).and_yield.and_return(cached_response2)

        get :show, params: { url: url2, fields: fields }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when different fields are provided' do
      let(:fields2) { ActionController::Parameters.new(header: '.header', description: '.description').permit! }
      let(:sorted_fields_string2) { fields2.to_h.sort.to_s }
      let(:cache_key2) { "requests/#{Digest::MD5.hexdigest(url)}/#{Digest::MD5.hexdigest(sorted_fields_string2)}" }
      let(:scraper_result2) { { header: 'Some header', description: 'Some description' } }
      let(:cached_response2) { { result: scraper_result2, error: nil, success: true } }

      before do
        allow(Scrapper).to receive(:new).with(url, fields2).and_return(scraper)
        Rails.cache.write(cache_key, cached_response) # Cache for fields1
      end

      it 'uses a different cache key for different fields' do
        expect(Rails.cache).to receive(:fetch).with(cache_key2, expires_in: 1.hour).and_yield.and_return(cached_response2)

        get :show, params: { url: url, fields: fields2 }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when fields parameter is missing' do
      it 'returns 400 with error' do
        expect do
          get :show, params: { url: url }
        end.to raise_error(ActionController::ParameterMissing)
      end
    end
  end
end