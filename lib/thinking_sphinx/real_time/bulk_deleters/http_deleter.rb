# frozen_string_literal: true

require "net/http"
require "json"

module ThinkingSphinx
  module RealTime
    module BulkDeleters
      class HttpDeleter
        attr_reader :index_name, :document_ids, :configuration

        def initialize(index_name, document_ids, configuration = ThinkingSphinx::Configuration.instance)
          @index_name = index_name
          @document_ids = Array(document_ids)
          @configuration = configuration
        end

        def execute
          return if document_ids.empty?

          ndjson   = build_ndjson
          response = post_bulk(ndjson)
          handle_response(response)
        end

        private

        def build_ndjson
          document_ids.map { |document_id| build_delete_line(document_id) }.join("\n")
        end

        def build_delete_line(document_id)
          JSON.generate(
            delete: {
              index: index_name,
              id: document_id,
            },
          )
        end

        def post_bulk(ndjson)
          uri = URI("http://#{host}:#{port}/bulk")

          Net::HTTP.start(uri.host, uri.port, open_timeout: 5, read_timeout: 60) do |http|
            request = Net::HTTP::Post.new(uri)
            request["Content-Type"] = "application/x-ndjson"
            request.body = ndjson
            http.request(request)
          end
        rescue StandardError => e
          raise ThinkingSphinx::ConnectionError,
                "HTTP bulk delete failed: #{e.message}"
        end

        def handle_response(response)
          case response
          when Net::HTTPSuccess
            check_for_item_errors(response.body)
          else
            raise ThinkingSphinx::QueryError,
                  "HTTP bulk delete returned #{response.code}: #{response.body}"
          end
        end

        def check_for_item_errors(body)
          result = JSON.parse(body)

          result["items"]&.each do |item|
            if item["delete"] && item["delete"]["error"]
              error = item["delete"]["error"]
              ThinkingSphinx.output.puts(
                "Bulk delete item error: #{error}"
              )
            end
          end
        rescue JSON::ParserError => e
          raise ThinkingSphinx::QueryError,
                "Failed to parse bulk delete response: #{e.message}"
        end

        def host
          configuration.searchd.address || "127.0.0.1"
        end

        def port
          configuration.searchd.http || 9308
        end
      end
    end
  end
end
