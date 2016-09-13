module Spree
  class Promotion
    module Actions
      class FreeShipping < Spree::PromotionAction
        def perform(payload = {})
          order = payload[:order]
          promotion_code = payload[:promotion_code]

          results = order.shipments.map do |shipment|
            return false if promotion_credit_exists?(shipment)
            shipment.adjustments.create!(
              order: shipment.order,
              amount: compute_amount(shipment),
              source: self,
              promotion_code: promotion_code,
              label: label
            )
            true
          end
          # Did we actually end up applying any adjustments?
          # If so, then this action should be classed as 'successful'
          results.any? { |r| r == true }
        end

        def label
          "#{Spree.t(:promotion)} (#{promotion.name})"
        end

        def compute_amount(shipment)
          shipment.cost * -1
        end

        private

        def promotion_credit_exists?(shipment)
          shipment.adjustments.where(source: self).exists?
        end
      end
    end
  end
end
