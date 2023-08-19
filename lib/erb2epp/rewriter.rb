# frozen_string_literal: true

require 'ripper'
require 'set'

module Erb2epp
  # Rewrite code from Ruby ERB to Puppet EPP
  class Rewriter
    LOCAL_VARS_SKIP_TOKENS = Set.new(" -\n(,)=".chars).freeze
    IF_SKIP_TOKENS = Set.new(" -\n".chars).freeze

    def initialize
      @epp_params = Set.new
      @local_vars = Set.new
    end

    # Store block variable names to prepend with '$' later
    def collect_vars_in_pipes(tokens)
      res = []
      tokens.each do |type, value|
        case type
        when :on_ident
          @local_vars << value
        end
        res << [type, value]
      end
      res
    end

    # Store local variable names to prepend with '$' later
    # Look for "var =" or "(var1, var2) ="
    def collect_local_vars(tokens)
      maybe_vars = Set.new
      tokens.each do |type, value|
        case type
        when :on_ident
          maybe_vars << value
        else
          break unless LOCAL_VARS_SKIP_TOKENS.include? value # Not an evaluation

          if value == '='
            @local_vars |= maybe_vars
            break
          end
        end
      end
    end

    # Rewrite local variables
    def rewrite_local_vars(tokens)
      res = []
      tokens.each do |type, value|
        case type
        when :on_ident
          value = "$#{value}" if @local_vars.include? value
        end
        res << [type, value]
      end
      res
    end

    # Add an opening curly bracked to the end of `if` statement line
    def rewrite_if(tokens)
      return tokens unless tokens.count { |x| x[1] == '{' }.zero?

      # We need the opening bracket
      ocb_pos = tokens.size - 1
      # Go back until non-[ -\n] found
      ocb_pos -= 1 while IF_SKIP_TOKENS.include? tokens[ocb_pos][1]

      res = tokens[..ocb_pos]
      res << [:on_sp, ' ']
      res << [:on_kw, '{']
      res.concat tokens[ocb_pos + 1..]
      res
    end

    # Swap opening curly bracket and block vars: {|x| ..} => |x| {..}
    def rewrite_blockvars(tokens)
      pos = { lbrace: 0, lpipe: 0, rpipe: 0 }
      res = []
      idx = 0
      tokens.each do |token|
        _, value = token
        case value
        when '{'
          pos[:lbrace] = idx
        when '|'
          pos[(pos[:lpipe].positive? ? :rpipe : :lpipe)] = idx if pos[:lbrace].positive?
        end
        res << token
        idx += 1
        next unless pos.values.all?(&:positive?)

        # When every position is positive then we found the whole "{ |...|" string, time to rewrite it
        new_res = res[0..(pos[:lbrace]) - 1]                             # copy everything before lbrace
        new_res << [:on_sp, ' '] if new_res.last[0] != :on_sp            # add space if none
        new_res.concat collect_vars_in_pipes(res[(pos[:lpipe])..(pos[:rpipe])]) # from lpipe to rpipe
        new_res << [:on_sp, ' ']     # space before lbrace
        new_res << [:on_lbrace, '{'] # lbrace

        pos = { lbrace: 0, lpipe: 0, rpipe: 0 }
        res = new_res
        idx = res.length
      end
      res
    end

    # Rewrite a piece of Ruby code
    def rewrite_code(code)
      tokens = rewrite_tokens(code)
      rewritten_code = tokens.map { |x| x[1] }.join

      tokens = rewrite_if(tokens) if /^[- ]*if/.match? rewritten_code
      tokens = rewrite_blockvars(tokens) if /{[^}]*?\|[^\|]*?\|/.match? rewritten_code

      collect_local_vars(tokens) if /[a-z][A-Za-z0-9_(), ]*=/.match? rewritten_code
      tokens = rewrite_local_vars(tokens)

      # Cannot use rewritten_code here as tokens might be modified
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
          @epp_params << v
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
        r << [type, value] if r.empty?
        res.concat(r)
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
      @epp_params.sort.each { |v| output << "  #{v}," }
      output << '| -%>'
      output << epp

      @epp_params.clear
      @local_vars.clear

      output.join("\n")
    end
  end
end
