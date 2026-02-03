# frozen_string_literal: true

require 'net/http'
require 'json'

module ThinkingSphinx
  module RealTime
    module BulkInserters
      class HttpInserter < Base
        def execute
          ndjson   = build_ndjson
          response = post_bulk(ndjson)
          handle_response(response)
        end

        private

        def build_ndjson
          values.map { |row| build_insert_line(row) }.join("\n")
        end

        def build_insert_line(row)
          document_id = row.first
          attributes  = columns.zip(row).drop(1).to_h

          JSON.generate(
            insert: {
              index: index.name,
              id:    document_id,
              doc:   attributes
            }
          )
        end

        def post_bulk(ndjson)
          uri = URI("http://#{host}:#{port}/bulk")

          Net::HTTP.start(uri.host, uri.port, open_timeout: 5, read_timeout: 60) do |http|
            request = Net::HTTP::Post.new(uri)
            request['Content-Type'] = 'application/x-ndjson'
            request.body = ndjson
            http.request(request)
          end
        rescue StandardError => error
          raise ThinkingSphinx::ConnectionError,
            "HTTP bulk import failed: #{error.message}"
        end

        def handle_response(response)
          case response
          when Net::HTTPSuccess
            check_for_item_errors(response.body)
          else
            raise ThinkingSphinx::QueryError,
              "HTTP bulk import returned #{response.code}: #{response.body}"
          end
        end

        def check_for_item_errors(body)
          result = JSON.parse(body)

          if result['items']
            result['items'].each do |item|
              if item['insert'] && item['insert']['error']
                error = item['insert']['error']
                ThinkingSphinx.output.puts(
                  "Bulk insert item error: #{error}"
                )
              end
            end
          end
        rescue JSON::ParserError => error
          raise ThinkingSphinx::QueryError,
            "Failed to parse bulk import response: #{error.message}"
        end

        def host
          configuration.searchd.address || '127.0.0.1'
        end

        def port
          configuration.searchd.http || 9308
        end
      end
    end
  end
end
