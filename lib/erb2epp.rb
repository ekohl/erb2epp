# frozen_string_literal: true

# ERB to EPP conversion module
module Erb2epp
  require 'erb2epp/rewriter'
  require 'erb2epp/parser'

  def self.run(input = $stdin, output = $stdout)
    parser = Erb2epp::Parser.new
    rewriter = Erb2epp::Rewriter.new

    ast = parser.call(input.read)
    output.puts rewriter.call(ast)
  end
end
