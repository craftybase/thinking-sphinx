# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ThinkingSphinx::RealTime::BulkInserters::HttpInserter do
  let(:index)         { double('index', :name => 'article_core') }
  let(:columns)       { ['id', 'title', 'content', 'views'] }
  let(:values)        { [[1, 'First', 'Content 1', 100], [2, 'Second', 'Content 2', 200]] }
  let(:inserter)      { described_class.new(index, columns, values) }
  let(:configuration) { double('configuration') }
  let(:searchd)       { double('searchd', :address => '127.0.0.1', :http => 9308) }
  let(:http)          { double('http') }
  let(:response)      { double('response', :code => '200', :body => '{"items":[]}') }

  before do
    allow(ThinkingSphinx::Configuration).to receive(:instance).
      and_return(configuration)
    allow(configuration).to receive(:searchd).and_return(searchd)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(response)
  end

  describe '#execute' do
    it 'posts ndjson to the /bulk endpoint' do
      expect(http).to receive(:request) do |request|
        expect(request).to be_a(Net::HTTP::Post)
        expect(request.path).to eq('/bulk')
        expect(request['Content-Type']).to eq('application/x-ndjson')
        expect(request.body).to include('"insert"')
        expect(request.body).to include('"article_core"')
      end.and_return(response)

      inserter.execute
    end

    it 'uses the correct host and port' do
      expect(Net::HTTP).to receive(:start).
        with('127.0.0.1', 9308, open_timeout: 5, read_timeout: 60).
        and_yield(http)

      inserter.execute
    end

    it 'generates ndjson with correct format' do
      expect(http).to receive(:request) do |request|
        lines = request.body.split("\n")
        expect(lines.size).to eq(2)

        first = JSON.parse(lines[0])
        expect(first['insert']['index']).to eq('article_core')
        expect(first['insert']['id']).to eq(1)
        expect(first['insert']['doc']).to eq({
          'id' => 1,
          'title' => 'First',
          'content' => 'Content 1',
          'views' => 100
        })

        second = JSON.parse(lines[1])
        expect(second['insert']['id']).to eq(2)
      end.and_return(response)

      inserter.execute
    end

    context 'when searchd address is nil' do
      before do
        allow(searchd).to receive(:address).and_return(nil)
      end

      it 'defaults to 127.0.0.1' do
        expect(Net::HTTP).to receive(:start).
          with('127.0.0.1', 9308, open_timeout: 5, read_timeout: 60).
          and_yield(http)

        inserter.execute
      end
    end

    context 'when http port is nil' do
      before do
        allow(searchd).to receive(:http).and_return(nil)
      end

      it 'defaults to 9308' do
        expect(Net::HTTP).to receive(:start).
          with('127.0.0.1', 9308, open_timeout: 5, read_timeout: 60).
          and_yield(http)

        inserter.execute
      end
    end

    context 'when network error occurs' do
      before do
        allow(http).to receive(:request).and_raise(Errno::ECONNREFUSED)
      end

      it 'raises a ConnectionError' do
        expect {
          inserter.execute
        }.to raise_error(ThinkingSphinx::ConnectionError, /HTTP bulk import failed/)
      end
    end

    context 'when HTTP request fails' do
      let(:response) { double('response', :code => '500', :body => 'Internal Error') }

      it 'raises a QueryError' do
        expect {
          inserter.execute
        }.to raise_error(ThinkingSphinx::QueryError, /returned 500/)
      end
    end

    context 'when response contains item errors' do
      let(:response) do
        double('response', :code => '200', :body => JSON.generate({
          'items' => [
            { 'insert' => { 'status' => 200 } },
            { 'insert' => { 'error' => 'field mismatch' } }
          ]
        }))
      end

      it 'logs the error without raising' do
        expect(ThinkingSphinx.output).to receive(:puts).
          with(/field mismatch/)

        expect { inserter.execute }.not_to raise_error
      end
    end

    context 'when response is not valid JSON' do
      let(:response) { double('response', :code => '200', :body => 'not json') }

      it 'raises a QueryError' do
        expect {
          inserter.execute
        }.to raise_error(ThinkingSphinx::QueryError, /Failed to parse/)
      end
    end
  end
end
