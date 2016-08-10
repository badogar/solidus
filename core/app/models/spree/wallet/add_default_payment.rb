class Spree::Wallet::AddDefaultPayment
  def initialize(order)
    @order = order
  end

  # Build a payment to be added to an order prior to moving into the "payment"
  # state.
  #
  # @return [Payment] the unsaved payment to be added, or nil if none.
  def build_payment
    credit_card = order.user.try!(:default_credit_card)

    if credit_card.try!(:valid?) && order.payments.from_credit_card.count == 0
      Spree::Payment.new(
        payment_method_id: credit_card.payment_method_id,
        source: credit_card,
      )
    end
  end

  private

  attr_reader :order
end
