# sublime: x_syntax Packages/Ruby/Ruby.tmLanguage
# sublime: translate_tabs_to_spaces true; tab_size 2

class Hash
  def deep_merge!(other)
    replace(deep_merge(other))
  end

  def deep_merge(other)
    Marshal.load(Marshal.dump(self)).merge(other) { |key, a, b|
      Hash === a && Hash === b ? a.deep_merge(b) : b
    }
  end

  def symbolize_keys!
    replace(symbolize_keys)
  end

  def symbolize_keys
    {}.tap { |result|
      each do |key, value|
        result[(key.to_sym rescue key)] = case value
          when Hash then value.symbolize_keys
          when Array then value.collect { |v| v.is_a?(Hash) ? v.symbolize_keys : v }
          else value
        end
      end
    }
  end
end
