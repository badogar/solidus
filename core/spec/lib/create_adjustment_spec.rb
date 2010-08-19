require "spec_helper"

# Its pretty difficult to test this module in isolation b/c it needs to work in conjunction with an actual class that
# extends ActiveRecord::Base and has a corresponding table in the database.  So we'll just test it using Order and
# ShippingMethod instead since those classes are including the module.
describe Spree::CreateAdjustments do

  let(:calculator) { mock_model(Calculator, :compute => 10, :[]= => nil) }

  it "should add has_one :calculator relationship" do
    assert ShippingMethod.reflect_on_all_associations(:has_one).map(&:name).include?(:calculator)
  end
  it "should be able to register calculators" do
    expect {
      TaxRate.register_calculator(calculator)
    }.to change { TaxRate.calculators.count }.by 1
  end

  let(:tax_rate) { TaxRate.new(:calculator => calculator) }

  context "#create_adjustment and the resulting adjustment" do
    let(:order) { Order.create }
    let(:target) { order }

    it "should be associated with the target" do
      target.adjustments.should_receive(:create)
      tax_rate.create_adjustment(target, order)
    end

    it "should have the correct originator and an amount derived from the calculator and supplied calculable" do
      adjustment = tax_rate.create_adjustment(target, order)
      adjustment.should_not be_nil
      adjustment.amount.should == 10
      adjustment.source.should == order
      adjustment.originator.should == tax_rate
    end
  end

  context "#update_adjustment" do
    it "should update the adjustment using its calculator (and the specified source)" do
      adjustment = mock :adjustment
      calculable = mock :calculable
      adjustment.should_receive(:amount=).with(10)
      tax_rate.update_adjustment(adjustment, calculable)
    end
  end

end