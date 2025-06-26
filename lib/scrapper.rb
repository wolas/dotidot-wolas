require "net/http"
require "uri"
require "nokogiri"

# A class for scraping HTML content from a specified URL, extracting text from elements
# matching given CSS selectors, and collecting metadata from meta tags.
class Scrapper
  # @return [String, nil] The error message if scraping failed, nil otherwise.
  attr_reader :error

  # @return [Hash] The scraped data, with field names as keys and extracted text as values,
  #   plus a :meta key with metadata if specified.
  attr_reader :result

  # Initializes a new Scrapper instance.
  #
  # @param url [String] The URL to scrape.
  # @param fields [Hash] A hash mapping field names (symbols or strings) to CSS selectors
  #   (strings). Optionally includes a :meta key with an array of meta tag names or
  #   properties to extract.
  # @return [Scrapper] A new Scrapper instance.
  #
  # @example
  #   scrapper = Scrapper.new('https://example.com', { title: 'h1', meta: ['description', 'og:title'] })
  def initialize(url, fields)
    dup_fields = fields.dup # we don't want to mess with the original object

    @url = URI.parse(url)
    @metadata_fields = Array(dup_fields.delete(:meta))
    @fields = dup_fields
    @document = nil
    @error = nil
    @result = {}
  end

  # Checks if the scraping operation was successful.
  #
  # @return [Boolean] true if no error occurred, false otherwise.
  #
  # @example
  #   scrapper.success? # => true or false
  def success?
    @error.blank?
  end

  # Performs the scraping operation by fetching HTML, extracting fields, and collecting metadata.
  #
  # @return [Scrapper] self (the Scrapper instance).
  # @side_effects Populates @result with scraped data and @error if an error occurs.
  #
  # @example
  #   scrapper.call
  def call
    get_html
    return self unless success?

    extract_fields
    extract_metadata

    self
  end

  private

  # Extracts content from meta tags with specified name or property attributes.
  #
  # @side_effects Populates @result[:meta] with a hash of meta tag values.
  def extract_metadata
    return unless @metadata_fields.any?

    @result[:meta] ||= {}
    tags = @document.css("meta").select { |tag| (tag["name"] || tag["property"]).in? @metadata_fields }

    tags.each { |tag| @result[:meta][tag["name"] || tag["property"]] = tag["content"] }
  end

  # Extracts text from elements matching the CSS selectors in @fields.
  #
  # @side_effects Populates @result with field names as keys and extracted text as values.
  def extract_fields
    @fields.each do |field_name, selector|
      @result[field_name] = @document.css(selector).map(&:text).join(" ").strip
    end
  end

  # Fetches HTML from the URL and parses it with Nokogiri.
  #
  # @side_effects Sets @document to a Nokogiri::HTML::Document on success, or @error on failure.
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
