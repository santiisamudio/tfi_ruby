require "test_helper"
require "socket"

class CatalogDownloadTest < ActiveSupport::TestCase
  setup do
    @catalog = {
      "version" => "2026-11-17.1",
      "generado" => "2026-11-17",
      "fuente" => "Catalogo de prueba",
      "cripticos" => [ { "id" => "cr-001" } ]
    }
  end

  test "downloads JSON by HTTP without writing catalog or sync records" do
    requests = Queue.new
    with_http_server(->(client) {
      requests << read_request(client)
      send_response(client, @catalog.to_json)
    }) do |url|
      assert_no_difference [ "Cryptic.count", "CatalogSync.count" ] do
        assert_equal @catalog, Catalog::Download.call(source_url: "#{url}/cryptics.json")
      end
      request = requests.pop
      assert_includes request, "GET /cryptics.json HTTP/1.1"
      assert_match(/Accept: application\/json/i, request)
    end
  end

  test "reports HTTP failures and does not follow redirects" do
    [ "500 Internal Server Error", "302 Found" ].each do |status|
      with_response("error", status: status) do |url|
        error = assert_raises(Catalog::Download::Error) { Catalog::Download.call(source_url: url) }
        assert_equal "http_error", error.code
        assert_includes error.message, status.split.first
      end
    end
  end

  test "reports malformed JSON separately from invalid catalog structure" do
    with_response("not JSON") do |url|
      error = assert_raises(Catalog::Download::Error) { Catalog::Download.call(source_url: url) }
      assert_equal "invalid_json", error.code
    end

    [
      [],
      @catalog.except("version"),
      @catalog.merge("version" => 1),
      @catalog.merge("fuente" => ""),
      @catalog.merge("cripticos" => {})
    ].each do |catalog|
      with_response(catalog.to_json) do |url|
        error = assert_raises(Catalog::Download::Error) { Catalog::Download.call(source_url: url) }
        assert_equal "invalid_catalog", error.code
      end
    end
  end

  test "rejects invalid or unsupported source URLs before connecting" do
    [ nil, "", "not a URL", "file:///catalog.json", "ftp://example.com/catalog.json",
      "https://user:password@example.com/catalog.json", "https://example.com/catalog.json#part" ].each do |url|
      error = assert_raises(Catalog::Download::Error) { Catalog::Download.call(source_url: url) }
      assert_equal "invalid_source_url", error.code
    end
  end

  test "reports refused connections" do
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close

    error = assert_raises(Catalog::Download::Error) do
      Catalog::Download.call(source_url: "http://127.0.0.1:#{port}/catalog.json")
    end
    assert_equal "network_error", error.code
  end

  test "enforces a total ten second deadline even while the server keeps sending data" do
    with_http_server(->(client) {
      read_request(client)
      client.write("HTTP/1.1 200 OK\r\nContent-Length: 100\r\nConnection: close\r\n\r\n")
      30.times do
        client.write(" ")
        sleep 0.5
      end
    }) do |url|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      error = assert_raises(Catalog::Download::Error) { Catalog::Download.call(source_url: url) }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      assert_equal "timeout", error.code
      assert_operator elapsed, :>=, 9
      assert_operator elapsed, :<, 12
    end
  end

  private
    def with_response(body, status: "200 OK", &block)
      with_http_server(->(client) {
        read_request(client)
        send_response(client, body, status: status)
      }, &block)
    end

    def with_http_server(handler)
      server = TCPServer.new("127.0.0.1", 0)
      url = "http://127.0.0.1:#{server.addr[1]}"
      worker = Thread.new do
        client = server.accept
        begin
          handler.call(client)
        ensure
          client.close
        end
      end
      yield url
    ensure
      worker&.kill
      worker&.join
      server&.close
    end

    def read_request(client)
      request = +""
      while (line = client.gets)
        request << line
        break if line == "\r\n"
      end
      request
    end

    def send_response(client, body, status: "200 OK")
      client.write(
        "HTTP/1.1 #{status}\r\nContent-Type: application/json\r\n" \
        "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
      )
    end
end
