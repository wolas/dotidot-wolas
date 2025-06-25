require 'net/http'
require 'uri'
require 'nokogiri'

class Scrapper
  attr_reader :error, :result

  def initialize(url, fields)
    @url = URI.parse(url)
    @fields = fields
    @document = nil
    @error = nil
    @result = {}
  end

  def success?
    @error.blank?
  end

  def call
    get_html
    return self unless success?

    @fields.each do |field_name, selector|
      @result[field_name] = @document.css(selector).map(&:text).join(' ').strip
    end

    self
  end

  private

  def get_html
    response = Net::HTTP.get_response(@url)

    case response
      when Net::HTTPSuccess then @document = Nokogiri::HTML(response.body)
      else @error = "Request failed with status: #{response.code}"
    end
  rescue StandardError => e
    @error = "Error fetching URL: #{e.message}"
  end
end