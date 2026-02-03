# frozen_string_literal: true

module ThinkingSphinx
  module RealTime
    module BulkInserters
      class SqlInserter < Base
        def execute
          ThinkingSphinx::Connection.take do |connection|
            query = Riddle::Query::Insert.new(index.name, columns, values)
            query.replace!

            connection.execute query.to_sql
          end
        end
      end
    end
  end
end
