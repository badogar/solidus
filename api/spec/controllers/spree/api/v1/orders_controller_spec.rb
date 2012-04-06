require 'spec_helper'

module Spree
  describe Api::V1::OrdersController do
    render_views

    let!(:order) { Factory(:order) }
    let(:attributes) { [:number, :item_total, :total,
                        :state, :adjustment_total, :credit_total,
                        :user_id, :created_at, :updated_at,
                        :completed_at, :payment_total, :shipment_state,
                        :payment_state, :email, :special_instructions] }


    before do
      stub_authentication!
    end

    it "cannot view all orders" do
      api_get :index
      assert_unauthorized!
    end

    it "can view their own order" do
      Order.any_instance.stub :user => current_api_user
      api_get :show, :id => order.to_param
      response.status.should == 200
      json_response.should have_attributes(attributes)
    end

    it "can not view someone else's order" do
      Order.any_instance.stub :user => stub_model(User)
      api_get :show, :id => order.to_param
      assert_unauthorized!
    end

    it "can create an order" do
      variant = Factory(:variant)
      api_post :create, :order => { :line_items => { variant.to_param => 5 } }
      response.status.should == 200
      order = Order.last
      order.line_items.count.should == 1
      order.line_items.first.variant.should == variant
      order.line_items.first.quantity.should == 5
      json_response["order"]["state"].should == "address"
    end

    context "working with an order" do
      it "can add address information to an order" do
        Factory(:payment_method)
        order.next # Switch from cart to address
        order.ship_address.should be_nil
        order.state.should == "address"

        address_params = { :country_id => Country.first.id, :state_id => State.first.id }
        shipping_address = Factory.attributes_for(:address).merge!(address_params)
        billing_address = Factory.attributes_for(:address).merge!(address_params)
        api_put :address, :id => order.to_param, :shipping_address => shipping_address, :billing_address => billing_address

        response.status.should == 200
        order.reload
        order.shipping_address.reload
        order.billing_address.reload
        # We can assume the rest of the parameters are set if these two are
        order.shipping_address.firstname.should == shipping_address[:firstname]
        order.billing_address.firstname.should == billing_address[:firstname]
        order.state.should == "delivery"
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can view all orders" do
        api_get :index
        json_response["orders"].first.should have_attributes(attributes)
        json_response["count"].should == 1
        json_response["current_page"].should == 1
        json_response["pages"].should == 1
      end
    end
  end
end
