# frozen_string_literal: true

require 'spec_helper'

describe Erb2epp::Rewriter do
  describe '.rewrite_code' do
    subject(:rewritten) { described_class.new.rewrite_code(code) }

    [
      {
        code: '',
        match: '',
      },
      {
        code: '@x',
        match: '$x',
      },
      {
        code: 'var_x = true',
        match: '$var_x = true',
      },
      {
        code: '(var1, var2) = var_arr',
        match: '($var1, $var2) = var_arr',
      },
      {
        code: 'if @x',
        match: 'if $x {',
      },
      {
        code: 'if @x && @y',
        match: 'if $x and $y {',
      },
      {
        code: 'if @x || @y',
        match: 'if $x or $y {',
      },
      {
        code: 'if @x then',
        match: 'if $x {',
      },
      {
        code: 'if @x {',
        match: 'if $x {',
      },
      {
        code: '@x.each do |k,v|',
        match: '$x.each |$k,$v| {',
      },
      {
        code: '@x.each {|k,v|',
        match: '$x.each |$k,$v| {',
      },
      {
        code: 'else',
        match: '} else {',
      },
      {
        code: 'end',
        match: '}',
      },
      # Ensure ERB comments are retained
      {
        code: '# the comment #',
        match: '# the comment #',
      },
      # Ensure whitespace control is retained
      {
        code: '- trim_left',
        match: '- trim_left',
      },
      {
        code: 'trim_right -',
        match: 'trim_right -',
      },
      {
        code: '- trim_both -',
        match: '- trim_both -',
      },
    ].each do |param|
      context "with code => '#{param[:code]}'" do
        let(:code) { param[:code] }

        it { is_expected.to eq(param[:match]) }
      end
    end
  end
end
