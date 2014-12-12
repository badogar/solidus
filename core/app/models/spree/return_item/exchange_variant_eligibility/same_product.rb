module Spree
  module ReturnItem::ExchangeVariantEligibility
    class SameProduct

      def self.eligible_variants(variant)
        if variant.is_master?
          Spree::Variant.where(product_id: variant.product_id, is_master: true).in_stock
        else
          Spree::Variant.where(product_id: variant.product_id, is_master: false).in_stock
        end
      end
    end
  end
end
