# frozen_string_literal: true

module ThinkingSphinx
  module RealTime
    module BulkInserters
      class Base
        attr_reader :index, :columns, :values

        def initialize(index, columns, values)
          @index   = index
          @columns = columns
          @values  = values
        end

        def execute
          raise NotImplementedError, "Subclasses must implement #execute"
        end

        private

        def configuration
          ThinkingSphinx::Configuration.instance
        end
      end
    end
  end
end
