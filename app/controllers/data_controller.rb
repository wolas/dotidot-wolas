class DataController < ApplicationController
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
      render json: cached_response[:result], status: 200
    else
      render json: cached_response[:result], status: 422
    end
  end

  private

  def fields_params
    params.require(:fields).permit!
  end
end