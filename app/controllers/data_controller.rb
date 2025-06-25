class DataController < ApplicationController
  def show
    scrapper = Scrapper.new(params[:url], fields_params).call

    if scrapper.success?
      render json: scrapper.result.to_json, status: 200
    else
      render json: scrapper.error, status: 422
    end
  end

  private

  def fields_params
    params.require(:fields).permit!
  end
end