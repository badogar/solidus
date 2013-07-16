require 'spec_helper'

module Spree
  describe Api::OrdersController do
    render_views

    let!(:order) { create(:order) }
    let(:attributes) { [:number, :item_total, :display_total, :total,
                        :state, :adjustment_total,
                        :user_id, :created_at, :updated_at,
                        :completed_at, :payment_total, :shipment_state,
                        :payment_state, :email, :special_instructions,
                        :total_quantity, :display_item_total] }


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
      json_response["adjustments"].should be_empty
      json_response["credit_cards"].should be_empty
    end

    it "orders contain the basic checkout steps" do
      Order.any_instance.stub :user => current_api_user
      api_get :show, :id => order.to_param
      response.status.should == 200
      json_response["checkout_steps"].should == ["address", "delivery", "complete"]
    end

    # Regression test for #1992
    it "can view an order not in a standard state" do
      Order.any_instance.stub :user => current_api_user
      order.update_column(:state, 'shipped')
      api_get :show, :id => order.to_param
    end

    it "can not view someone else's order" do
      Order.any_instance.stub :user => stub_model(Spree::LegacyUser)
      api_get :show, :id => order.to_param
      assert_unauthorized!
    end

    it "can view an order if the token is known" do
      api_get :show, :id => order.to_param, :order_token => order.token
      response.status.should == 200
    end

    it "cannot cancel an order that doesn't belong to them" do
      order.update_attribute(:completed_at, Time.now)
      order.update_attribute(:shipment_state, "ready")
      api_put :cancel, :id => order.to_param
      assert_unauthorized!
    end

    it "cannot add address information to an order that doesn't belong to them" do
      api_put :address, :id => order.to_param
      assert_unauthorized!
    end

    let(:address_params) { { :country_id => Country.first.id, :state_id => State.first.id } }
    let(:billing_address) { { :firstname => "Tiago", :lastname => "Motta", :address1 => "Av Paulista",
                              :city => "Sao Paulo", :zipcode => "1234567", :phone => "12345678",
                              :country_id => Country.first.id, :state_id => State.first.id} }
    let(:shipping_address) { { :firstname => "Tiago", :lastname => "Motta", :address1 => "Av Paulista",
                               :city => "Sao Paulo", :zipcode => "1234567", :phone => "12345678",
                               :country_id => Country.first.id, :state_id => State.first.id} }
    let!(:payment_method) { create(:payment_method) }
    let(:current_api_user) do
      user = Spree.user_class.new(:email => "spree@example.com")
      user.generate_spree_api_key!
      user
    end

    it "can create an order" do
      variant = create(:variant)
      api_post :create, :order => { :line_items => { "0" => { :variant_id => variant.to_param, :quantity => 5 } } }
      response.status.should == 201
      order = Order.last
      order.line_items.count.should == 1
      order.line_items.first.variant.should == variant
      order.line_items.first.quantity.should == 5
      json_response["token"].should_not be_blank
      json_response["state"].should == "cart"
      order.user.should == current_api_user
      order.email.should == current_api_user.email
      json_response["user_id"].should == current_api_user.id
    end

    it "can create an order with parameters" do
      variant = create(:variant)
      api_post :create, :order => {
        :email => 'test@spreecommerce.com',
        :ship_address => shipping_address,
        :bill_address => billing_address,
        :line_items => {
           "0" => { :variant_id => variant.to_param, :quantity => 5 } },
      }

      response.status.should == 201
      order = Order.last

      order.email.should == current_api_user.email
      order.ship_address.address1.should eq 'Av Paulista'
      order.bill_address.address1.should eq 'Av Paulista'
      order.line_items.count.should == 1
    end

    it "can create an order without any parameters" do
      lambda { api_post :create }.should_not raise_error
      response.status.should == 201
      order = Order.last
      json_response["state"].should == "cart"
    end

    context "working with an order" do
      before do
        Order.any_instance.stub :user => current_api_user
        order.line_items << FactoryGirl.create(:line_item)
        create(:payment_method)
        order.next # Switch from cart to address
        order.bill_address = nil
        order.ship_address = nil
        order.save
        order.state.should == "address"
      end

      def clean_address(address)
        address.delete(:state)
        address.delete(:country)
        address
      end

      let(:address_params) { { :country_id => Country.first.id, :state_id => State.first.id } }
      let(:billing_address) { { :firstname => "Tiago", :lastname => "Motta", :address1 => "Av Paulista",
                                :city => "Sao Paulo", :zipcode => "1234567", :phone => "12345678",
                                :country_id => Country.first.id, :state_id => State.first.id} }
      let(:shipping_address) { { :firstname => "Tiago", :lastname => "Motta", :address1 => "Av Paulista",
                                 :city => "Sao Paulo", :zipcode => "1234567", :phone => "12345678",
                                 :country_id => Country.first.id, :state_id => State.first.id} }
      let!(:payment_method) { create(:payment_method) }

      it "can update quantities of existing line items" do
        variant = create(:variant)
        line_item = order.line_items.create!(:variant_id => variant.id, :quantity => 1)

        api_put :update, :id => order.to_param, :order => {
          :line_items => {
            line_item.id => { :quantity => 10 }
          }
        }

        response.status.should == 200
        json_response['line_items'].count.should == 1
        json_response['line_items'].first['quantity'].should == 10
      end

      it "can add billing address" do
        api_put :update, :id => order.to_param, :order => { :bill_address_attributes => billing_address }

        order.reload.bill_address.should_not be_nil
      end

      it "receives error message if trying to add billing address with errors" do
        billing_address[:firstname] = ""

        api_put :update, :id => order.to_param, :order => { :bill_address_attributes => billing_address }

        json_response['error'].should_not be_nil
        json_response['errors'].should_not be_nil
        json_response['errors']['bill_address.firstname'].first.should eq "can't be blank"
      end

      it "can add shipping address" do
        order.ship_address.should be_nil

        api_put :update, :id => order.to_param, :order => { :ship_address_attributes => shipping_address }

        order.reload.ship_address.should_not be_nil
      end

      it "receives error message if trying to add shipping address with errors" do
        order.ship_address.should be_nil
        shipping_address[:firstname] = ""

        api_put :update, :id => order.to_param, :order => { :ship_address_attributes => shipping_address }

        json_response['error'].should_not be_nil
        json_response['errors'].should_not be_nil
        json_response['errors']['ship_address.firstname'].first.should eq "can't be blank"
      end

      context "with a line item" do
        before do
          create(:line_item, :order => order)
          order.reload
        end

        it "can empty an order" do
          api_put :empty, :id => order.to_param
          response.status.should == 200
          order.reload.line_items.should be_empty
        end

        it "can list its line items with images" do
          order.line_items.first.variant.images.create!(:attachment => image("thinking-cat.jpg"))

          api_get :show, :id => order.to_param

          json_response['line_items'].first['variant'].should have_attributes([:images])
        end

        it "lists variants product id" do
          api_get :show, :id => order.to_param

          json_response['line_items'].first['variant'].should have_attributes([:product_id])
        end

        context "when in delivery" do
          let!(:shipping_method) do
            FactoryGirl.create(:shipping_method).tap do |shipping_method|
              shipping_method.calculator.preferred_amount = 10
              shipping_method.calculator.save
            end
          end

          before do
            order.ship_address = FactoryGirl.create(:address)
            order.state = 'delivery'
            order.save
          end

          it "returns available shipments for an order" do
            api_get :show, :id => order.to_param
            response.status.should == 200
            json_response["shipments"].should_not be_empty
            shipment = json_response["shipments"][0]
            # Test for correct shipping method attributes
            # Regression test for #3206
            shipment["shipping_methods"].should_not be_nil
            json_shipping_method = shipment["shipping_methods"][0]
            json_shipping_method["id"].should == shipping_method.id
            json_shipping_method["name"].should == shipping_method.name
            json_shipping_method["zones"].should_not be_empty
            json_shipping_method["shipping_categories"].should_not be_empty

            # Test for correct shipping rates attributes
            # Regression test for #3206
            shipment["shipping_rates"].should_not be_nil
            shipping_rate = shipment["shipping_rates"][0]
            shipping_rate["name"].should == json_shipping_method["name"]
            shipping_rate["cost"].should == "10.0"
            shipping_rate["selected"].should be_true
            shipping_rate["display_cost"].should == "$10.00"

            shipment["stock_location_name"].should_not be_blank
            manifest_item = shipment["manifest"][0]
            manifest_item["quantity"].should == 1
            manifest_item["variant"].should have_attributes([:id, :name, :sku, :price])
          end
        end
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      context "with no orders" do
        before { Spree::Order.delete_all }
        it "still returns a root :orders key" do
          api_get :index
          json_response["orders"].should == []
        end
      end

      context "with two orders" do
        before { create(:order) }

        it "can view all orders" do
          api_get :index
          json_response["orders"].first.should have_attributes(attributes)
          json_response["count"].should == 2
          json_response["current_page"].should == 1
          json_response["pages"].should == 1
        end

        # Test for #1763
        it "can control the page size through a parameter" do
          api_get :index, :per_page => 1
          json_response["orders"].count.should == 1
          json_response["orders"].first.should have_attributes(attributes)
          json_response["count"].should == 1
          json_response["current_page"].should == 1
          json_response["pages"].should == 2
        end
      end

      context "search" do
        before do
          create(:order)
          Spree::Order.last.update_attribute(:email, 'spree@spreecommerce.com')
        end

        let(:expected_result) { Spree::Order.last }

        it "can query the results through a parameter" do
          api_get :index, :q => { :email_cont => 'spree' }
          json_response["orders"].count.should == 1
          json_response["orders"].first.should have_attributes(attributes)
          json_response["orders"].first["email"].should == expected_result.email
          json_response["count"].should == 1
          json_response["current_page"].should == 1
          json_response["pages"].should == 1
        end
      end

      context "can cancel an order" do
        before do
          Spree::Config[:mails_from] = "spree@example.com"

          order.completed_at = Time.now
          order.state = 'complete'
          order.shipment_state = 'ready'
          order.save!
        end

        specify do
          api_put :cancel, :id => order.to_param
          json_response["state"].should == "canceled"
        end
      end
    end
  end
end
