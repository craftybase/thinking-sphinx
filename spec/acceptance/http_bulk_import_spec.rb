# frozen_string_literal: true

require 'acceptance/spec_helper'

describe 'HTTP bulk import', :live do
  it "imports records via HTTP when configured" do
    # Save original setting
    original_protocol = ThinkingSphinx::Configuration.instance.settings['bulk_protocol']

    begin
      # Configure HTTP bulk import. The real-time transcriber reads this setting
      # at write time, so setting it before creating records routes the index
      # writes through the HTTP /bulk path (the feature under test).
      ThinkingSphinx::Configuration.instance.settings['bulk_protocol'] = 'http'

      # Create test product. For a real-time index this triggers indexing via
      # the configured bulk protocol immediately — no separate populate step.
      product = Product.create!(
        :name => 'HTTP Test Widget',
        :description => 'Testing HTTP bulk import functionality'
      )

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

      # Create multiple products, each indexed via the HTTP /bulk path on create.
      products = 50.times.map do |i|
        Product.create!(
          :name => "Bulk Product #{i}",
          :description => "Description for product #{i}"
        )
      end

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

      # Create product with different attribute types, indexed via HTTP on create.
      product = Product.create!(
        :name => 'Multi-type Product',
        :description => 'Has various attributes',
        :created_at => Time.now,
        :price => 99.99
      )

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
      # Explicitly set to mysql41 so writes go through the SQL inserter.
      ThinkingSphinx::Configuration.instance.settings['bulk_protocol'] = 'mysql41'

      product = Product.create!(
        :name => 'SQL Test Widget',
        :description => 'Testing SQL bulk import'
      )

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
      # Remove the setting to test default behavior (SQL inserter).
      ThinkingSphinx::Configuration.instance.settings.delete('bulk_protocol')

      product = Product.create!(
        :name => 'Default Protocol Widget',
        :description => 'Testing default protocol'
      )

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
end
