module Spree
  module Api
    module V1
      class OrdersController < BaseController
        def index
          # should probably look at turning this into a CanCan step
          raise CanCan::AccessDenied unless current_api_user.has_role?("admin")
          @orders = Order.page(params[:page])
        end

        def show
          @order = Order.find_by_number(params[:id])
          authorize! :read, @order
        end
      end
    end
  end
end
