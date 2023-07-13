# frozen_string_literal: true

require 'temple'
require 'ripper'

# Rewrite code from Ruby ERB to Puppet EPP
class Erb2epp
  def initialize
    @vars_found = []
  end

  # Rewrite a piece of Ruby code
  #
  # The ruby code blocks in ERB are not full programs so a parser can't be
  # used. A lexer is used instead.
  def rewrite_code(code)
    tokens = Ripper.lex(code)
    res = []
    ops = {}

    # First pass: rewrite
    tokens.each do |token|
      # [[lineno, column], type, token, state]
      _, type, value, _state = token
      r = value

      case type
      when :on_ivar
        r = value.gsub(/@([a-z][A-Za-z0-9_]*)/, '$\1')
        @vars_found.push r
      when :on_op
        case value
        when '||'
          r = 'or'
        when '&&'
          r = 'and'
        end
      when :on_kw
        case value
        when 'if'
          ops['if'] = true
        when 'then'
          r = '{'
          ops['if'] = false
        when 'do', '{'
          r = '{'
        when 'else'
          r = '} else {'
        when 'end'
          r = '}'
        end
      end

      res.push r
    end

    # Append `{` to the `if` code line
    res.push '{ ' if ops['if'] == true

    # Assemble the tokens again
    res.join
  rescue StandardError
    warn code
    raise
  end

  def walk_erb(node)
    out = ''
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
    else
      warn "Unknown ERB node type #{node[0]}"
      exit(1)
    end

    out
  end

  def run(input = $stdin, output = $stdout)
    parser = Temple::ERB::Parser.new
    ast = parser.call(input)
    epp = walk_erb(ast)

    output.puts '<%- |'
    @vars_found.sort.uniq.each { |v| output.puts "  #{v}," }
    output.puts '| -%>'
    output.puts epp
  end
end
