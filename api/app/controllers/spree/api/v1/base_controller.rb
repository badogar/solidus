module Spree
  module Api
    module V1
      class BaseController < ActionController::Metal
        include Spree::Api::ControllerSetup

        attr_accessor :current_api_user

        before_filter :check_for_api_key
        before_filter :authenticate_user

        rescue_from CanCan::AccessDenied, :with => :unauthorized
        rescue_from ActiveRecord::RecordNotFound, :with => :not_found

        helper Spree::Api::ApiHelpers

        private

        def check_for_api_key
          render "spree/api/v1/errors/must_specify_api_key", :status => 401 and return if api_key.blank?
        end

        def authenticate_user
          unless @current_api_user = User.find_by_api_key(api_key)
            render "spree/api/v1/errors/invalid_api_key", :status => 401 and return
          end
        end

        def unauthorized
          render "spree/api/v1/errors/unauthorized", :status => 401 and return
        end

        def not_found
          render "spree/api/v1/errors/not_found", :status => 404 and return
        end

        def current_ability
          Spree::Ability.new(current_api_user)
        end

        def invalid_resource!(resource)
          render "spree/api/v1/errors/invalid_resource", :resource => resource, :status => 422
        end

        def api_key
          request.headers["X-Spree-Token"] || params[:token]
        end
        helper_method :api_key

        def find_product(id)
          @product ||= begin
            product_scope.find_by_permalink!(id)
          rescue ActiveRecord::RecordNotFound
            product_scope.find(id)
          end
        end

        def product_scope
          if current_api_user.has_role?("admin")
            scope = Product
          else
            scope = Product.active
          end

          scope.includes(:master)
        end

      end
    end
  end
end

