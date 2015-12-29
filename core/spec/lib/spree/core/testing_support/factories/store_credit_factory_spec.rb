ENV['NO_FACTORIES'] = "NO FACTORIES"

require 'spec_helper'
require 'spree/testing_support/factories/store_credit_factory'

RSpec.describe 'store credit factory' do
  let(:factory_class) { Spree::StoreCredit }

  describe 'plain store credit' do
    let(:factory) { :store_credit }

    it_behaves_like 'a working factory'
  end
end
