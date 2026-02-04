# frozen_string_literal: true

require 'acceptance/spec_helper'

describe 'HTTP bulk import', :live do
  it "imports records via HTTP when configured" do
    # Save original setting
    original_protocol = ThinkingSphinx::Configuration.instance.settings['bulk_protocol']

    begin
      # Configure HTTP bulk import
      ThinkingSphinx::Configuration.instance.settings['bulk_protocol'] = 'http'

      # Create test products
      product = Product.create!(
        :name => 'HTTP Test Widget',
        :description => 'Testing HTTP bulk import functionality'
      )

      # Trigger index population
      index.real_time_indices.each(&:clear)
      ThinkingSphinx::RealTime::Populator.populate(index)

      # Verify the product was indexed
      results = Product.search('HTTP Test Widget')
      expect(results.to_a).to include(product)

      # Verify we can search by description
      results = Product.search('bulk import')
      expect(results.to_a).to include(product)
    ensure
      # Restore original setting
      if original_protocol
        ThinkingSphinx::Configuration.instance.settings['bulk_protocol'] = original_protocol
      else
        ThinkingSphinx::Configuration.instance.settings.delete('bulk_protocol')
      end
    end
  end

  it "handles large batches efficiently via HTTP" do
    original_protocol = ThinkingSphinx::Configuration.instance.settings['bulk_protocol']

    begin
      ThinkingSphinx::Configuration.instance.settings['bulk_protocol'] = 'http'

      # Create multiple products
      products = 50.times.map do |i|
        Product.create!(
          :name => "Bulk Product #{i}",
          :description => "Description for product #{i}"
        )
      end

      # Populate index
      index.real_time_indices.each(&:clear)
      ThinkingSphinx::RealTime::Populator.populate(index)

      # Verify all products are searchable
      results = Product.search('Bulk Product')
      expect(results.total_entries).to eq(50)

      # Verify specific product
      results = Product.search('Bulk Product 25')
      expect(results.to_a.map(&:name)).to include('Bulk Product 25')
    ensure
      if original_protocol
        ThinkingSphinx::Configuration.instance.settings['bulk_protocol'] = original_protocol
      else
        ThinkingSphinx::Configuration.instance.settings.delete('bulk_protocol')
      end
    end
  end

  it "handles various attribute types via HTTP" do
    original_protocol = ThinkingSphinx::Configuration.instance.settings['bulk_protocol']

    begin
      ThinkingSphinx::Configuration.instance.settings['bulk_protocol'] = 'http'

      # Create product with different attribute types
      product = Product.create!(
        :name => 'Multi-type Product',
        :description => 'Has various attributes',
        :created_at => Time.now,
        :price => 99.99
      )

      # Populate and search
      index.real_time_indices.each(&:clear)
      ThinkingSphinx::RealTime::Populator.populate(index)

      results = Product.search('Multi-type')
      expect(results.to_a).to include(product)
    ensure
      if original_protocol
        ThinkingSphinx::Configuration.instance.settings['bulk_protocol'] = original_protocol
      else
        ThinkingSphinx::Configuration.instance.settings.delete('bulk_protocol')
      end
    end
  end

  it "falls back to SQL when bulk_protocol is mysql41" do
    original_protocol = ThinkingSphinx::Configuration.instance.settings['bulk_protocol']

    begin
      # Explicitly set to mysql41
      ThinkingSphinx::Configuration.instance.settings['bulk_protocol'] = 'mysql41'

      product = Product.create!(
        :name => 'SQL Test Widget',
        :description => 'Testing SQL bulk import'
      )

      index.real_time_indices.each(&:clear)
      ThinkingSphinx::RealTime::Populator.populate(index)

      results = Product.search('SQL Test Widget')
      expect(results.to_a).to include(product)
    ensure
      if original_protocol
        ThinkingSphinx::Configuration.instance.settings['bulk_protocol'] = original_protocol
      else
        ThinkingSphinx::Configuration.instance.settings.delete('bulk_protocol')
      end
    end
  end

  it "uses SQL by default when no bulk_protocol is set" do
    original_protocol = ThinkingSphinx::Configuration.instance.settings['bulk_protocol']

    begin
      # Remove the setting to test default behavior
      ThinkingSphinx::Configuration.instance.settings.delete('bulk_protocol')

      product = Product.create!(
        :name => 'Default Protocol Widget',
        :description => 'Testing default protocol'
      )

      index.real_time_indices.each(&:clear)
      ThinkingSphinx::RealTime::Populator.populate(index)

      results = Product.search('Default Protocol')
      expect(results.to_a).to include(product)
    ensure
      if original_protocol
        ThinkingSphinx::Configuration.instance.settings['bulk_protocol'] = original_protocol
      else
        ThinkingSphinx::Configuration.instance.settings.delete('bulk_protocol')
      end
    end
  end

  def index
    ThinkingSphinx::Configuration.instance.index('product')
  end
end
