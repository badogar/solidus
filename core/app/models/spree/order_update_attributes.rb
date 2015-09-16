module Spree
  class OrderUpdateAttributes
    def initialize(order, attributes, request_env: nil)
      @order = order
      @attributes = attributes.dup
      @payments_attributes = @attributes.delete(:payments_attributes) || []
      @request_env = request_env
    end

    def apply
      assign_order_attributes
      assign_payments_attributes

      if order.save
        order.set_shipments_cost if order.shipments.any?
        true
      else
        false
      end
    end

    private

    attr_reader :attributes, :payments_attributes, :order

    def assign_order_attributes
      order.attributes = attributes
    end

    def assign_payments_attributes
      @payments_attributes.each do |payment_attributes|
        PaymentCreate.new(order, payment_attributes, request_env: @request_env).build
      end
    end
  end
end
