require 'spec_helper'

describe Spree::OrderPopulator do
  let(:order) { double('Order') }
  subject { Spree::OrderPopulator.new(order, "USD") }

  context "with stubbed out find_variant" do
    let(:variant) { double('Variant', :name => "T-Shirt", :options_text => "Size: M") }
    before { Spree::Variant.stub(:find).and_return(variant) }

    context "with products parameters" do
      it "can take a list of products and add them to the order" do
        subject.stub(:check_stock_levels => true)
        order.should_receive(:add_variant).with(variant, 1, subject.currency)
        subject.populate(:products => { 1 => 2 }, :quantity => 1)
      end

      it "does not add any products if a quantity is set to 0" do
        order.should_not_receive(:add_variant)
        subject.populate(:products => { 1 => 2 }, :quantity => 0)
      end

      it "should add an error if the variant is out of stock" do
        variant.stub :in_stock? => false

        order.should_not_receive(:add_variant)
        subject.populate(:products => { 1 => 2 }, :quantity => 1) 
        subject.should_not be_valid
        subject.errors.full_messages.join("").should == %Q{"T-Shirt (Size: M)" is out of stock.}
      end

      it "should add an error if the variant does not have enough stock on hand" do
        variant.stub :in_stock? => true

        # Regression test for #2382
        variant.should_receive(:on_hand).and_return(2)

        order.should_not_receive(:add_variant)
        subject.populate(:products => { 1 => 2 }, :quantity => 3)
        subject.should_not be_valid
        output = %Q{There are only 2 of \"T-Shirt (Size: M)\" remaining.} +
                 %Q{ Please select a quantity less than or equal to this value.}
        subject.errors.full_messages.join("").should == output
      end
    end

    context "with variant parameters" do
      it "can take a list of variants with quantites and add them to the order" do
        subject.stub(:check_stock_levels => true)
        order.should_receive(:add_variant).with(variant, 5, subject.currency)
        subject.populate(:variants => { 2 => 5 })
      end
    end
  end
end
