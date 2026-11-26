require "net/http"
require "json"
require "timeout"

class Catalog::Download
  DEFAULT_SOURCE_URL = "https://ecorrons.github.io/cryptics-api/v1/cryptics.json".freeze
  TIMEOUT_SECONDS = 10

  class Error < StandardError
    attr_reader :code

    def initialize(code, **options)
      @code = code.to_s
      super(I18n.t("catalog.errors.#{code}", **options, raise: true))
    end
  end

  def self.call(source_url: DEFAULT_SOURCE_URL)
    uri = parse_url(source_url)
    response = Timeout.timeout(TIMEOUT_SECONDS) do
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = TIMEOUT_SECONDS
      http.read_timeout = TIMEOUT_SECONDS
      http.write_timeout = TIMEOUT_SECONDS
      http.max_retries = 0
      http.start do |connection|
        request = Net::HTTP::Get.new(uri.request_uri)
        request["Accept"] = "application/json"
        connection.request(request)
      end
    end
    unless response.is_a?(Net::HTTPSuccess)
      raise Error.new(:http_error, status: response.code)
    end

    catalog = JSON.parse(response.body)
    unless catalog.is_a?(Hash) &&
        %w[version generado fuente].all? { |key| catalog[key].is_a?(String) && catalog[key].present? } &&
        catalog["cripticos"].is_a?(Array)
      raise Error.new(:invalid_catalog)
    end
    catalog
  rescue Timeout::Error
    raise Error.new(:timeout)
  rescue JSON::ParserError
    raise Error.new(:invalid_json)
  rescue SocketError, SystemCallError, IOError, EOFError, OpenSSL::SSL::SSLError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError
    raise Error.new(:network_error)
  end

  def self.parse_url(source_url)
    raise Error.new(:invalid_source_url) unless source_url.is_a?(String)

    uri = URI.parse(source_url)
    unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil? && uri.fragment.nil?
      raise Error.new(:invalid_source_url)
    end
    uri
  rescue URI::InvalidURIError
    raise Error.new(:invalid_source_url)
  end
  private_class_method :parse_url
end
