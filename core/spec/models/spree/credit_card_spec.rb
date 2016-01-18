require 'spec_helper'

describe Spree::CreditCard, type: :model do
  let(:valid_credit_card_attributes) do
    {
      number: '4111111111111111',
      verification_value: '123',
      expiry: "12 / #{(Time.current.year + 1).to_s.last(2)}",
      name: 'Spree Commerce'
    }
  end

  def self.payment_states
    Spree::Payment.state_machine.states.keys
  end

  let(:credit_card) { Spree::CreditCard.new }

  before(:each) do

    @order = create(:order)
    @payment = Spree::Payment.create(:amount => 100, :order => @order)

    @success_response = double('gateway_response', success?: true, authorization: '123', avs_result: { 'code' => 'avs-code' })
    @fail_response = double('gateway_response', success?: false)

    @payment_gateway = mock_model(Spree::PaymentMethod,
      payment_profiles_supported?: true,
      authorize: @success_response,
      purchase: @success_response,
      capture: @success_response,
      void: @success_response,
      credit: @success_response,
    )

    allow(@payment).to receive_messages payment_method: @payment_gateway
  end

  context "#can_capture?" do
    it "should be true if payment is pending" do
      payment = mock_model(Spree::Payment, pending?: true, created_at: Time.current)
      expect(credit_card.can_capture?(payment)).to be true
    end

    it "should be true if payment is checkout" do
      payment = mock_model(Spree::Payment, pending?: false, checkout?: true, created_at: Time.current)
      expect(credit_card.can_capture?(payment)).to be true
    end
  end

  context "#can_void?" do
    it "should be true if payment is not void" do
      payment = mock_model(Spree::Payment, failed?: false, void?: false)
      expect(credit_card.can_void?(payment)).to be true
    end
  end

  context "#can_credit?" do
    it "should be false if payment is not completed" do
      payment = mock_model(Spree::Payment, completed?: false)
      expect(credit_card.can_credit?(payment)).to be false
    end

    it "should be false when credit_allowed is zero" do
      payment = mock_model(Spree::Payment, completed?: true, credit_allowed: 0, order: mock_model(Spree::Order, payment_state: 'credit_owed'))
      expect(credit_card.can_credit?(payment)).to be false
    end
  end

  context "#valid?" do
    it "should validate presence of number" do
      credit_card.attributes = valid_credit_card_attributes.except(:number)
      expect(credit_card).not_to be_valid
      expect(credit_card.errors[:number]).to eq(["can't be blank"])
    end

    it "should validate presence of security code" do
      credit_card.attributes = valid_credit_card_attributes.except(:verification_value)
      expect(credit_card).not_to be_valid
      expect(credit_card.errors[:verification_value]).to eq(["can't be blank"])
    end

    it "validates name presence" do
      credit_card.valid?
      expect(credit_card.error_on(:name).size).to eq(1)
    end

    it "should only validate on create" do
      credit_card.attributes = valid_credit_card_attributes
      credit_card.save
      expect(credit_card).to be_valid
    end

    context "encrypted data is present" do
      it "does not validate presence of number or cvv" do
        credit_card.encrypted_data = "$fdgsfgdgfgfdg&gfdgfdgsf-"
        credit_card.valid?
        expect(credit_card.errors[:number]).to be_empty
        expect(credit_card.errors[:verification_value]).to be_empty
      end
    end

    context "imported is true" do
      it "does not validate presence of number or cvv" do
        credit_card.imported = true
        credit_card.valid?
        expect(credit_card.errors[:number]).to be_empty
        expect(credit_card.errors[:verification_value]).to be_empty
      end
    end
  end

  context "#save" do
    before do
      credit_card.attributes = valid_credit_card_attributes
      credit_card.save!
    end

    let!(:persisted_card) { Spree::CreditCard.find(credit_card.id) }
    let(:valid_address_attributes) do
      {
        firstname: "Hugo",
        lastname: "Furst",
        address1: "123 Main",
        city: "Somewhere",
        country_id: 1,
        zipcode: 55_555,
        phone: "1234567890"
      }
    end

    it "should not actually store the number" do
      expect(persisted_card.number).to be_blank
    end

    it "should not actually store the security code" do
      expect(persisted_card.verification_value).to be_blank
    end

    it "should save and update addresses through nested attributes" do
      persisted_card.update_attributes({address_attributes: valid_address_attributes})
      persisted_card.save!
      updated_attributes = {id: persisted_card.address.id, address1: "123 Main St."}
      persisted_card.update_attributes({address_attributes: updated_attributes})
      expect(persisted_card.address.address1).to eq "123 Main St."
    end
  end

  context "#number=" do
    it "should strip non-numeric characters from card input" do
      credit_card.number = "6011000990139424"
      expect(credit_card.number).to eq("6011000990139424")

      credit_card.number = "  6011-0009-9013-9424  "
      expect(credit_card.number).to eq("6011000990139424")
    end

    it "should not raise an exception on non-string input" do
      credit_card.number = Hash.new
      expect(credit_card.number).to be_nil
    end
  end

  # Regression test for https://github.com/spree/spree/issues/3847 and https://github.com/spree/spree/issues/3896
  context "#expiry=" do
    it "can set with a 2-digit month and year" do
      credit_card.expiry = '04 / 15'
      expect(credit_card.month).to eq('4')
      expect(credit_card.year).to eq('2015')
    end

    it "can set with a 2-digit month and 4-digit year" do
      credit_card.expiry = '04 / 2015'
      expect(credit_card.month).to eq('4')
      expect(credit_card.year).to eq('2015')
    end

    it "can set with a 2-digit month and 4-digit year without whitespace" do
      credit_card.expiry = '04/15'
      expect(credit_card.month).to eq('4')
      expect(credit_card.year).to eq('2015')
    end

    it "can set with a 2-digit month and 4-digit year without whitespace" do
      credit_card.expiry = '04/2015'
      expect(credit_card.month).to eq('4')
      expect(credit_card.year).to eq('2015')
    end

    it "can set with a 2-digit month and 4-digit year without whitespace and slash" do
      credit_card.expiry = '042015'
      expect(credit_card.month).to eq('4')
      expect(credit_card.year).to eq('2015')
    end

    it "can set with a 2-digit month and 2-digit year without whitespace and slash" do
      credit_card.expiry = '0415'
      expect(credit_card.month).to eq('4')
      expect(credit_card.year).to eq('2015')
    end

    it "does not blow up when passed an empty string" do
      credit_card.expiry = ''
    end

    # Regression test for https://github.com/spree/spree/issues/4725
    it "does not blow up when passed one number" do
      credit_card.expiry = '12'
    end

  end

  context "#cc_type=" do
    it "converts between the different types" do
      credit_card.cc_type = 'mastercard'
      expect(credit_card.cc_type).to eq('master')

      credit_card.cc_type = 'maestro'
      expect(credit_card.cc_type).to eq('master')

      credit_card.cc_type = 'amex'
      expect(credit_card.cc_type).to eq('american_express')

      credit_card.cc_type = 'dinersclub'
      expect(credit_card.cc_type).to eq('diners_club')

      credit_card.cc_type = 'some_outlandish_cc_type'
      expect(credit_card.cc_type).to eq('some_outlandish_cc_type')
    end

    it "assigns the type based on card number in the event of js failure" do
      credit_card.number = '4242424242424242'
      credit_card.cc_type = ''
      expect(credit_card.cc_type).to eq('visa')

      credit_card.number = '5555555555554444'
      credit_card.cc_type = ''
      expect(credit_card.cc_type).to eq('master')

      credit_card.number = '378282246310005'
      credit_card.cc_type = ''
      expect(credit_card.cc_type).to eq('american_express')

      credit_card.number = '30569309025904'
      credit_card.cc_type = ''
      expect(credit_card.cc_type).to eq('diners_club')

      credit_card.number = '3530111333300000'
      credit_card.cc_type = ''
      expect(credit_card.cc_type).to eq('jcb')

      credit_card.number = ''
      credit_card.cc_type = ''
      expect(credit_card.cc_type).to eq('')

      credit_card.number = nil
      credit_card.cc_type = ''
      expect(credit_card.cc_type).to eq('')
    end
  end

  context "#associations" do
    it "should be able to access its payments" do
      credit_card.payments.to_a
    end
  end

  context "#first_name" do
    before do
      credit_card.name = "Ludwig van Beethoven"
    end

    it "extracts the first name" do
      expect(credit_card.first_name).to eq "Ludwig"
    end
  end

  context "#last_name" do
    before do
      credit_card.name = "Ludwig van Beethoven"
    end

    it "extracts the last name" do
      expect(credit_card.last_name).to eq "van Beethoven"
    end
  end

  context "#to_active_merchant" do
    before do
      credit_card.number = "4111111111111111"
      credit_card.year = Time.current.year
      credit_card.month = Time.current.month
      credit_card.name = "Ludwig van Beethoven"
      credit_card.verification_value = 123
    end

    it "converts to an ActiveMerchant::Billing::CreditCard object" do
      am_card = credit_card.to_active_merchant
      expect(am_card.number).to eq("4111111111111111")
      expect(am_card.year).to eq(Time.current.year)
      expect(am_card.month).to eq(Time.current.month)
      expect(am_card.first_name).to eq("Ludwig")
      expect(am_card.last_name).to eq("van Beethoven")
      expect(am_card.verification_value).to eq(123)
    end
  end

  it 'ensures only one credit card per user is default at a time' do
    user = FactoryGirl.create(:user)
    first = FactoryGirl.create(:credit_card, user: user, default: true)
    second = FactoryGirl.create(:credit_card, user: user, default: true)

    expect(first.reload.default).to eq false
    expect(second.reload.default).to eq true

    first.default = true
    first.save!

    expect(first.reload.default).to eq true
    expect(second.reload.default).to eq false
  end

  it 'allows default credit cards for different users' do
    first = FactoryGirl.create(:credit_card, user: FactoryGirl.create(:user), default: true)
    second = FactoryGirl.create(:credit_card, user: FactoryGirl.create(:user), default: true)

    expect(first.reload.default).to eq true
    expect(second.reload.default).to eq true
  end

  it 'allows this card to save even if the previously default card has expired' do
    user = FactoryGirl.create(:user)
    first = FactoryGirl.create(:credit_card, user: user, default: true)
    second = FactoryGirl.create(:credit_card, user: user, default: false)
    first.update_columns(year: DateTime.current.year, month: 1.month.ago.month)

    second.update_attributes!(default: true)
  end

  it 'allows this card to save even if the previously default card has expired' do
    user = FactoryGirl.create(:user)
    first = FactoryGirl.create(:credit_card, user: user, default: true)
    second = FactoryGirl.create(:credit_card, user: user, default: false)
    first.update_columns(year: DateTime.current.year, month: 1.month.ago.month)

    second.update_attributes!(default: true)
  end
end
