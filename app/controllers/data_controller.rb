class DataController < ApplicationController
  # Retrieves scraped data for a given URL and fields, caching the result for 1 hour.
  #
  # @param url [String] The URL to scrape, passed as a query parameter.
  # @param fields [Hash] A hash of field names to CSS selectors, passed as a nested parameter.
  # @return [void] Renders JSON with the scraped result or error.
  # @raise [ActionController::ParameterMissing] If the :fields parameter is missing.
  #
  # @example Request
  #   GET /data?url=https://example.com&fields[title]=h1&fields[meta][]=description
  #
  # @example Success Response (status: 200)
  #   { "title": "Example Page", "meta": { "description": "Sample site" } }
  #
  # @example Error Response (status: 422)
  #   { "error": "Request failed with status: 404" }
  def show
    url = params[:url]
    sorted_params = fields_params.to_h.sort.to_s # So that {a: 1, b:2 } is the same as {b: 2, a: 1}
    cache_key = "requests/#{Digest::MD5.hexdigest(url)}/#{Digest::MD5.hexdigest(sorted_params)}"
    scrapper = Scrapper.new(url, fields_params)

    cached_response = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      scrapper.call

      { result: scrapper.result, error: scrapper.error, success: scrapper.success? }
    end

    if cached_response[:success]
      render json: cached_response[:result], status: :ok
    else
      render json: cached_response[:result], status: :unprocessable_content
    end
  end

  private

  def fields_params
    params.require(:fields).permit!
  end
end
