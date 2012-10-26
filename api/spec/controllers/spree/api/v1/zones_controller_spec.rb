require 'spec_helper'

module Spree
  describe Api::V1::ZonesController do
    render_views

    let!(:attributes) { [:id, :name, :zone_members] }

    before do
      stub_authentication!
      @zone = create(:zone, :name => 'Europe')
    end

    it "gets list of zones" do
      api_get :index
      json_response.first.should have_attributes(attributes)
    end

    it "gets a zone" do
      api_get :show, :id => @zone.id
      json_response.should have_attributes(attributes)
      json_response['zone']['name'].should eq @zone.name
      json_response['zone']['zone_members'].size.should eq @zone.zone_members.count
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can create a new zone" do
        params = {
          :name => "North Pole",
          :zone_members => [
            { 
              :zoneable_type => "Spree::Country",
              :zoneable_id => 1
            }
          ]
        }

        response.status.should == 201
        json_response.should have_attributes(attributes)
        json_response["zone"]["zone_members"].should_not be_empty
      end

      it "updates a zone" do
        params = { :id => 1,
          :zone => {
            :name => "North Pole",
            :zone_members => [
              {
                :zoneable_type => "Spree::Country",
                :zoneable_id => 1
              }
            ]
          }
        }

        api_put :update, params 
        response.status.should == 200
        json_response['zone']['name'].should eq 'Americas'
        json_response['zone']['zone_members'].should_not be_blank
      end

      it "can delete a zone" do
        api_delete :destroy, :id => @zone.id
        response.status.should == 204
        lambda { @zone.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
