require File.dirname(__FILE__) + '/../spec_helper'

describe Product do

  context "shoulda validations" do
    it { should belong_to(:tax_category) }
    it { should belong_to(:shipping_category) }
    it { should have_many(:product_option_types) }
    it { should have_many(:option_types) }
    it { should have_many(:product_properties) }
    it { should have_many(:properties) }
    it { should have_many(:images) }
    it { should have_and_belong_to_many(:product_groups) }
    it { should have_and_belong_to_many(:taxons) }
    it { should validate_presence_of(:price) }
    it { should validate_presence_of(:permalink) }
  end

  context "factory_girl" do
    let(:product) { Factory(:product) }
    it 'should have a saved product record' do
      product.new_record?.should be_false
    end
    it 'should have a master variant' do
      product.master.should be_true
    end
  end
end
