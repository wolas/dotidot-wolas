require 'net/http'
require 'uri'
require 'nokogiri'

class Scrapper
  attr_reader :error, :result

  def initialize(url, fields)
    dup_fields = fields.dup # we don't want to mess with the original object

    @url = URI.parse(url)
    @metadata_fields = Array(dup_fields.delete(:meta))
    @fields = dup_fields
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
    
    extract_fields
    extract_metadata

    self
  end

  private

  def extract_metadata
    return unless @metadata_fields.any?

    @result[:meta] ||= {}
    tags = @document.css('meta').select { |tag| (tag['name'] || tag['property']).in? @metadata_fields }

    tags.each { |tag| @result[:meta][tag['name'] || tag['property']] = tag['content'] }
  end

  def extract_fields
    @fields.each do |field_name, selector|
      @result[field_name] = @document.css(selector).map(&:text).join(' ').strip
    end
  end

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