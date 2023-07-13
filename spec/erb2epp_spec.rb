# frozen_string_literal: true

require 'spec_helper'

describe Erb2epp do
  describe '.rewrite_code' do
    subject(:rewritten) { described_class.new.rewrite_code(code) }

    context 'with empty string' do
      let(:code) { '' }

      it { is_expected.to eq('') }
    end

    context 'with an instance variable' do
      let(:code) { '@x' }

      it { is_expected.to eq('$x') }
    end

    context 'with simple if' do
      let(:code) { 'if @x' }

      it { is_expected.to eq('if $x {') }
    end
  end
end
