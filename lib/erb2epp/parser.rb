# frozen_string_literal: true

require 'temple'

module Erb2epp
  # Parse an ERB template to Temple S-expressions respecting the whitespace control
  class Parser < Temple::Parser
    ERB_PATTERN = /(\n|<%%|%%>)|<%(=|\#)?(.*?)?%>/m.freeze

    def call(input)
      result = [:multi]
      pos = 0

      input.scan(ERB_PATTERN) do |token, indicator, code|
        lm = Regexp.last_match
        text = input[pos...lm.begin(0)]
        pos  = lm.end(0)
        if token
          case token
          when "\n"
            result << [:static, "#{text}\n"] << [:newline]
          when '<%%', '%%>'
            result << [:static, text] unless text.empty?
            token.slice!(1)
            result << [:static, token]
          end
        else
          result << [:static, text] unless text.empty?

          result <<
            case indicator
            when '#'
              [:comment, code]
            when '=', '=='
              [:escape, indicator.size == 2, [:dynamic, code]]
            else
              [:code, code]
            end
        end
      end
      result << [:static, input[pos..]]

      result
    end
  end
end
