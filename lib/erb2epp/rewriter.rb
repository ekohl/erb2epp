# frozen_string_literal: true

require 'ripper'

module Erb2epp
  # Rewrite code from Ruby ERB to Puppet EPP
  class Rewriter
    def initialize
      @vars_found = []
    end

    def on_if(tokens)
      tcode = tokens.map { |x| x[1] }.join
      ocb_count = tcode.count('{')
      ccb_count = tcode.count('}')
      if ocb_count.zero? || ocb_count < ccb_count
        # We need the closing bracket
        ocb_pos = tokens.size - 1
        # Go back until non-[ -\n] found
        ignored_tokens = %i[on_nl on_op on_sp].freeze
        ocb_pos -= 1 while ignored_tokens.include? tokens[ocb_pos][0]
        tokens.insert(ocb_pos + 1, [:on_sp, ' '], [:on_kw, '{'])
      end

      tokens
    end

    # Rewrite a piece of Ruby code
    def rewrite_code(code)
      tokens = rewrite_tokens(code)
      on_if(tokens) if /^[- ]*if/.match? code

      tokens.map { |x| x[1] }.join
    end

    # The ruby code blocks in ERB are not full programs so a parser can't be
    # used. A lexer is used instead.
    def rewrite_tokens(code)
      tokens = Ripper.lex(code)
      res = []

      # First pass: rewrite
      tokens.each do |token|
        # [[lineno, column], type, token, state]
        _, type, value, _state = token
        r = []

        case type
        when :on_ivar
          v = value.gsub(/@([a-z][A-Za-z0-9_]*)/, '$\1')
          @vars_found.push v
          r << [type, v]
        when :on_op
          case value
          when '||'
            r << [type, 'or']
          when '&&'
            r << [type, 'and']
          end
        when :on_kw
          case value
          when 'then', 'do'
            r << [:on_lbrace, '{']
          when 'else'
            r << [:on_rbrace, '}']
            r << [:on_sp, ' ']
            r << [:on_kw, 'else']
            r << [:on_sp, ' ']
            r << [:on_lbrace, '{']
          when 'end'
            r << [:on_rbrace, '}']
          end
        end

        res << (r.empty? ? [type, value] : r.flatten)
      end

      res
    rescue StandardError
      warn code
      raise
    end

    def walk_erb(node)
      out = +''
      case node[0]
      when :multi
        node[1..].each do |n|
          out << walk_erb(n)
        end
      when :static
        out << node[1]
      when :newline
        # Eat the newline
      when :code
        # Handle <%
        out << "<%#{rewrite_code(node[1])}%>"
      when :escape
        # Handle <%=
        # TODO: node[1] is a boolean, what to do with it?
        out << '<%='
        out << walk_erb(node[2])
        out << '%>'
      when :dynamic
        # Handle ruby code
        out << rewrite_code(node[1])
      when :comment
        out << "<%##{node[1]}%>"
      else
        warn "Unknown ERB node type #{node[0]}"
        exit(1)
      end

      out
    end

    def call(ast)
      epp = walk_erb(ast)

      output = ['<%- |']
      @vars_found.sort.uniq.each { |v| output << "  #{v}," }
      output << '| -%>'
      output << epp

      @vars_found = []
      output.join("\n")
    end
  end
end
