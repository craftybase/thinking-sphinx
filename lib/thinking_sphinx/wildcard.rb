# frozen_string_literal: true

class ThinkingSphinx::Wildcard
  DEFAULT_TOKEN = /\p{Word}+/

  def self.call(query, pattern = DEFAULT_TOKEN)
    new(query, pattern).call
  end

  def initialize(query, pattern = DEFAULT_TOKEN)
    @query   = query || ''
    @pattern = pattern.is_a?(Regexp) ? pattern : DEFAULT_TOKEN
  end

  def call
    query.gsub(extended_pattern) do
      pre, proper, post = $`, $&, $'
      # E.g. "@foo", "/2", "~3", but not as part of a token pattern
      is_operator = pre.match(%r{@$}) ||
                    pre.match(%r{([^\\]+|\A)[~/]\Z}) ||
                    pre.match(%r{(\W|^)@\([^\)]*$})
      # E.g. "foo bar", with quotes
      is_quote    = proper[/^".*"$/]
      has_star    = post[/\*$/] || pre[/^\*/]
      is_min_len  = proper.size < min_prefix_len
      if is_operator || is_quote || has_star || is_min_len
        proper
      else
        "*#{proper}*"
      end
    end
  end

  private

  attr_reader :query, :pattern

  def extended_pattern
    Regexp.new(
      "(\"#{pattern}(.*?#{pattern})?\"|(?![!-])#{pattern})".encode('UTF-8')
    )
  end

  def min_prefix_len
    ThinkingSphinx::Configuration.instance.settings["min_prefix_len"] || 0
  end
end
