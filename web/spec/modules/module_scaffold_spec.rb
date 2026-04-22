# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Module scaffold', spec: "specifications/system/infrastructure/concept.md#module-scaffold" do
  MODULES = %w[Agents Sandbox Analytics].freeze

  describe 'namespace resolution' do
    MODULES.each do |mod|
      it "#{mod} module resolves without NameError" do
        expect { Object.const_get(mod) }.not_to raise_error
      end
    end
  end

  describe 'LOOKUP.md files' do
    it 'app/modules/LOOKUP.md exists' do
      expect(Rails.root.join('app/modules/LOOKUP.md')).to exist
    end

    it 'specifications/practices/LOOKUP.md exists' do
      expect(Pathname.new('/specifications/practices/LOOKUP.md')).to exist
    end
  end
end
