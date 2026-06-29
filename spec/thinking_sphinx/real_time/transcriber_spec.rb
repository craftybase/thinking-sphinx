# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ThinkingSphinx::RealTime::Transcriber do
  let(:subject)       { ThinkingSphinx::RealTime::Transcriber.new index }
  let(:index)         { double 'index', :name => 'foo_core', :conditions => [],
    :fields => [double(:name => 'field_a'), double(:name => 'field_b')],
    :attributes => [double(:name => 'attr_a'), double(:name => 'attr_b')],
    :primary_key => :id }
  let(:insert)        { double :replace! => replace, :to_sql => 'REPLACE QUERY' }
  let(:replace)       { double }
  let(:connection)    { double :execute => true }
  let(:instance_a)    { double :id => 48, :persisted? => true }
  let(:instance_b)    { double :id => 49, :persisted? => true }
  let(:properties_a)  { double }
  let(:properties_b)  { double }
  let(:configuration) { double('configuration', :settings => {}) }

  before :each do
    allow(Riddle::Query::Insert).to receive(:new).and_return(insert)
    allow(ThinkingSphinx::Connection).to receive(:take).and_yield(connection)
    allow(ThinkingSphinx::RealTime::TranscribeInstance).to receive(:call).
      with(instance_a, index, anything).and_return(properties_a)
    allow(ThinkingSphinx::RealTime::TranscribeInstance).to receive(:call).
      with(instance_b, index, anything).and_return(properties_b)
    allow(ThinkingSphinx::Configuration).to receive(:instance).
      and_return(configuration)
  end

  it "generates a SphinxQL command" do
    expect(Riddle::Query::Insert).to receive(:new).with(
      'foo_core',
      ['id', 'field_a', 'field_b', 'attr_a', 'attr_b'],
      [properties_a, properties_b]
    )

    subject.copy instance_a, instance_b
  end

  it "executes the SphinxQL command" do
    expect(connection).to receive(:execute).with('REPLACE QUERY')

    subject.copy instance_a, instance_b
  end

  it "deletes previous records" do
    expect(connection).to receive(:execute).
      with('DELETE FROM foo_core WHERE sphinx_internal_id IN (48, 49)')

    subject.copy instance_a, instance_b
  end

  it "skips instances that aren't in the database" do
    allow(instance_a).to receive(:persisted?).and_return(false)

    expect(Riddle::Query::Insert).to receive(:new).with(
      'foo_core',
      ['id', 'field_a', 'field_b', 'attr_a', 'attr_b'],
      [properties_b]
    )

    subject.copy instance_a, instance_b
  end

  it "skips instances that fail a symbol condition" do
    index.conditions << :ok?
    allow(instance_a).to receive(:ok?).and_return(true)
    allow(instance_b).to receive(:ok?).and_return(false)

    expect(Riddle::Query::Insert).to receive(:new).with(
      'foo_core',
      ['id', 'field_a', 'field_b', 'attr_a', 'attr_b'],
      [properties_a]
    )

    subject.copy instance_a, instance_b
  end

  it "skips instances that fail a Proc condition" do
    index.conditions << Proc.new { |instance| instance.ok? }
    allow(instance_a).to receive(:ok?).and_return(true)
    allow(instance_b).to receive(:ok?).and_return(false)

    expect(Riddle::Query::Insert).to receive(:new).with(
      'foo_core',
      ['id', 'field_a', 'field_b', 'attr_a', 'attr_b'],
      [properties_a]
    )

    subject.copy instance_a, instance_b
  end

  it "skips instances that throw an error while transcribing values" do
    error = ThinkingSphinx::TranscriptionError.new
    error.instance = instance_a
    error.inner_exception = StandardError.new

    allow(ThinkingSphinx::RealTime::TranscribeInstance).to receive(:call).
      with(instance_a, index, anything).
      and_raise(error)
    allow(ThinkingSphinx.output).to receive(:puts).and_return(nil)

    expect(Riddle::Query::Insert).to receive(:new).with(
      'foo_core',
      ['id', 'field_a', 'field_b', 'attr_a', 'attr_b'],
      [properties_b]
    )

    subject.copy instance_a, instance_b
  end

  describe "inserter selection" do
    let(:sql_inserter)  { double('sql_inserter', :execute => true) }
    let(:http_inserter) { double('http_inserter', :execute => true) }

    before do
      allow(ThinkingSphinx::RealTime::BulkInserters::SqlInserter).
        to receive(:new).and_return(sql_inserter)
      allow(ThinkingSphinx::RealTime::BulkInserters::HttpInserter).
        to receive(:new).and_return(http_inserter)
    end

    context "with bulk_protocol set to 'http'" do
      before do
        configuration.settings['bulk_protocol'] = 'http'
      end

      it "uses the HttpInserter" do
        expect(ThinkingSphinx::RealTime::BulkInserters::HttpInserter).
          to receive(:new).with(index, anything, anything)

        subject.copy instance_a, instance_b
      end

      it "executes the HttpInserter" do
        expect(http_inserter).to receive(:execute)

        subject.copy instance_a, instance_b
      end
    end

    context "with bulk_protocol set to 'mysql41'" do
      before do
        configuration.settings['bulk_protocol'] = 'mysql41'
      end

      it "uses the SqlInserter" do
        expect(ThinkingSphinx::RealTime::BulkInserters::SqlInserter).
          to receive(:new).with(index, anything, anything)

        subject.copy instance_a, instance_b
      end
    end

    context "with no bulk_protocol setting" do
      it "defaults to SqlInserter" do
        expect(ThinkingSphinx::RealTime::BulkInserters::SqlInserter).
          to receive(:new).with(index, anything, anything)

        subject.copy instance_a, instance_b
      end
    end
  end
end
