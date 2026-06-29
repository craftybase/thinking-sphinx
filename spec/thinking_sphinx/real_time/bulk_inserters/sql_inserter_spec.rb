# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ThinkingSphinx::RealTime::BulkInserters::SqlInserter do
  let(:index)      { double('index', :name => 'article_core') }
  let(:columns)    { ['id', 'title', 'content'] }
  let(:values)     { [[1, 'First', 'Content 1'], [2, 'Second', 'Content 2']] }
  let(:inserter)   { described_class.new(index, columns, values) }
  let(:connection) { double('connection', :execute => true) }
  let(:query)      { double('query', :to_sql => 'REPLACE INTO ...') }

  before do
    allow(ThinkingSphinx::Connection).to receive(:take).and_yield(connection)
    allow(Riddle::Query::Insert).to receive(:new).
      with('article_core', columns, values).and_return(query)
    allow(query).to receive(:replace!).and_return(query)
  end

  describe '#execute' do
    it 'creates a Riddle::Query::Insert with the index name, columns, and values' do
      expect(Riddle::Query::Insert).to receive(:new).
        with('article_core', columns, values)

      inserter.execute
    end

    it 'marks the query as a REPLACE' do
      expect(query).to receive(:replace!)

      inserter.execute
    end

    it 'executes the SQL via the connection pool' do
      expect(connection).to receive(:execute).with('REPLACE INTO ...')

      inserter.execute
    end

    it 'uses the ThinkingSphinx::Connection pool' do
      expect(ThinkingSphinx::Connection).to receive(:take)

      inserter.execute
    end
  end
end
