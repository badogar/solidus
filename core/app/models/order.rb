class Order < ActiveRecord::Base
  module Totaling
    def total
      map(&:amount).sum
    end
  end

  attr_accessible :line_items, :bill_address, :ship_address
  #attr_protected :charge_total, :item_total, :total, :user, :user_id, :number, :token

  belongs_to :user

  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"
  belongs_to :ship_address, :foreign_key => "ship_address_id", :class_name => "Address"
  belongs_to :shipping_method
  has_many :state_events, :as => :stateful
  has_many :line_items, :extend => Totaling, :dependent => :destroy
  has_many :inventory_units
  has_many :payments, :dependent => :destroy, :extend => Totaling
  has_many :shipments, :dependent => :destroy
  has_many :return_authorizations, :dependent => :destroy

  accepts_nested_attributes_for :line_items
  accepts_nested_attributes_for :bill_address
  accepts_nested_attributes_for :ship_address
  accepts_nested_attributes_for :payments
  accepts_nested_attributes_for :shipments

  has_many :adjustments,      :extend => Totaling, :order => :position
  has_many :charges,          :extend => Totaling, :order => :position
  has_many :credits,          :extend => Totaling, :order => :position
  has_many :shipping_charges, :extend => Totaling, :order => :position
  has_many :tax_charges,      :extend => Totaling, :order => :position
  has_many :non_zero_charges, :extend => Totaling, :order => :position,
           :class_name => "Charge", :conditions => ["amount != 0"]

  before_create :create_user


  #delegate :shipping_method, :to => :checkout
  #delegate :email, :to => :checkout
  #delegate :ip_address, :to => :checkout
  #delegate :special_instructions, :to => :checkout

  #validates :item_total, :total, :numericality => true

  scope :by_number, lambda {|number| where("orders.number = ?", number)}
  scope :between, lambda {|*dates| where("orders.created_at between :start and :stop").where(:start, dates.first.to_date).where(:stop, dates.last.to_date)}
  scope :by_customer, lambda {|customer| where("uses.email =?", customer).includes(:user)}
  scope :by_state, lambda {|state| where("state = ?", state)}
  scope :complete, where("orders.completed_at IS NOT NULL")

  make_permalink :field => :number

  # attr_accessible is a nightmare with attachment_fu, so use attr_protected instead.
  attr_protected :charge_total, :item_total, :total, :user, :user_id, :number, :token #,:state

  # def to_param
  #   self.number if self.number
  #   generate_order_number unless self.number
  #   self.number.parameterize.to_s.upcase
  # end

  def complete?
    !! completed_at
  end

  def item_count
    line_items.map(&:quantity).sum
  end

  def empty?
    item_count == 0
  end



  # order state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'cart', :use_transactions => false do

    event :checkout do
      transition :to => 'address'
    end

    event :next do
      transition :to => 'delivery', :from => 'address'
      transition :to => 'payment', :from => 'delivery'
      transition :to => 'confirm', :from => 'payment'
      transition :to => 'complete', :from => 'confirm'
    end
    #TODO - add conditional confirmation step (only when gateway supports it, etc.)

    event :cancel do
      transition :to => 'canceled', :if => :allow_cancel?
    end
    event :return do
      transition :to => 'returned', :from => 'awaiting_return'
    end
    event :resume do
      transition :to => 'resumed', :from => 'canceled', :if => :allow_resume?
    end
    event :authorize_return do
      transition :to => 'awaiting_return'
    end

    after_transition :to => 'complete', :do => :finalize!

  end



  def restore_state
    # pop the resume event so we can see what the event before that was
    state_events.pop if state_events.last.name == "resume"
    update_attribute("state", state_events.last.previous_state)

    if paid?
      InventoryUnit.sell_units(self) if inventory_units.empty?
      shipment.inventory_units = inventory_units
      shipment.ready!
    end

  end


  before_validation :clone_billing_address, :if => "@use_billing"
  attr_accessor :use_billing

  def clone_billing_address
    if bill_address and self.ship_address.nil?
      self.ship_address = bill_address.clone
    else
      self.ship_address.attributes = bill_address.attributes.except("id", "updated_at", "created_at")
    end
    true
  end



  # def make_shipments_shipped
  #   shipments.reject(&:shipped?).each do |shipment|
  #     shipment.update_attributes(:state => 'shipped', :shipped_at => Time.now)
  #   end
  # end
  #
  # def make_shipments_ready
  #   shipments.each(&:ready)
  # end
  #
  # def make_shipments_pending
  #   shipments.each(&:pend)
  # end
  #
  # def shipped_units
  #   shipped_units = shipments.inject([]) { |units, shipment| units.concat(shipment.shipped? ? shipment.inventory_units : []) }
  #   return nil if shipped_units.empty?
  #
  #   shipped = {}
  #   shipped_units.group_by(&:variant_id).each do |variant_id, ship_units|
  #     shipped[Variant.find(variant_id)] = ship_units.size
  #   end
  #   shipped
  # end

  # def returnable_units
  #   returned_units = return_authorizations.inject([]) { |units, return_auth| units << return_auth.inventory_units}
  #   returned_units.flatten! unless returned_units.nil?
  #
  #   returnable = shipped_units
  #   return if returnable.nil?
  #
  #   returned_units.group_by(&:variant_id).each do |variant_id, returned_units|
  #     variant = returnable.detect { |ru| ru.first.id == variant_id }[0]
  #
  #     count = returnable[variant] - returned_units.size
  #     if count > 0
  #       returnable[variant] = returnable[variant] - returned_units.size
  #     else
  #       returnable.delete variant
  #     end
  #   end
  #
  #   returnable.empty? ? nil : returnable
  # end

  def allow_cancel?
    self.state != 'canceled'
  end

  def allow_resume?
    # we shouldn't allow resume for legacy orders b/c we lack the information necessary to restore to a previous state
    return false if state_events.empty? || state_events.last.previous_state.nil?
    true
  end

  def add_variant(variant, quantity = 1)
    current_item = contains?(variant)
    if current_item
      current_item.increment_quantity unless quantity > 1
      current_item.quantity = (current_item.quantity + quantity) if quantity > 1
      current_item.save
    else
      current_item = LineItem.new(:quantity => quantity)
      current_item.variant = variant
      current_item.price   = variant.price
      self.line_items << current_item
    end

    # populate line_items attributes for additional_fields entries
    # that have populate => [:line_item]
    Variant.additional_fields.select{|f| !f[:populate].nil? && f[:populate].include?(:line_item) }.each do |field|
      value = ""

      if field[:only].nil? || field[:only].include?(:variant)
        value = variant.send(field[:name].gsub(" ", "_").downcase)
      elsif field[:only].include?(:product)
        value = variant.product.send(field[:name].gsub(" ", "_").downcase)
      end
      current_item.update_attribute(field[:name].gsub(" ", "_").downcase, value)
    end

    current_item
  end

  def generate_order_number
    record = true
    while record
      random = "R#{Array.new(9){rand(9)}.join}"
      record = Order.find(:first, :conditions => ["number = ?", random])
    end
    self.number = random
  end

  # convenience method since many stores will not allow user to create multiple shipments
  def shipment
    @shipment ||= shipments.last
  end

  def contains?(variant)
    line_items.detect{|line_item| line_item.variant_id = variant.id}
  end

  # def mark_shipped
  #   inventory_units.each do |inventory_unit|
  #     inventory_unit.ship!
  #   end
  # end

  # def payment_total
  #   payments.reload.total
  # end
  #
  # def ship_total
  #   shipping_charges.reload.total
  # end
  #
  # def tax_total
  #   tax_charges.reload.total
  # end
  #
  # def credit_total
  #   credits.reload.total.abs
  # end
  #
  # def charge_total
  #   charges.reload.total
  # end
  #
  # def create_tax_charge
  #   if tax_charges.empty?
  #     tax_charges.create({
  #         :order => self,
  #         :description => I18n.t(:tax),
  #         :adjustment_source => self
  #     })
  #   end
  # end
  #
  # def update_totals(force_adjustment_recalculation=false)
  #   self.item_total       = self.line_items.total
  #
  #   # save the items which might be changed by an order update, so that
  #   # charges can be recalculated accurately.
  #   self.line_items.map(&:save)
  #
  #   if !self.checkout_complete || force_adjustment_recalculation
  #     applicable_adjustments, adjustments_to_destroy = adjustments.partition{|a| a.applicable?}
  #     self.adjustments = applicable_adjustments
  #     adjustments_to_destroy.each(&:destroy)
  #   end
  #
  #   self.adjustment_total = self.charge_total - self.credit_total
  #   self.total            = self.item_total   + self.adjustment_total
  # end
  #
  # def update_totals!
  #   update_totals
  #
  #   payments_total = self.payments.total
  #   if payments_total < self.total
  #     #Total is higher so balance_due
  #     self.under_paid
  #   elsif payments_total > self.total
  #     #Total is lower so credit_owed
  #     self.over_paid
  #   end
  #
  #   save!
  # end
  #
  # def update_adjustments
  #   self.adjustments.each(&:update_amount)
  #   update_totals(:force_adjustment_update)
  #   self
  # end
  #
  

  # TODO: Not sure on method vs db column for this
  def outstanding_balance
    total - payment_total
  end

  def calculate_totals
    # update_adjustments
    self.payment_total = payments.finalized.map(&:amount).sum
    self.item_total = line_items.total
    self.adjustment_total = adjustments.total
    self.total = item_total + adjustment_total
    # self.outstanding_balance = total - payment_total
  end

  def update_adjustments
    destroy_inapplicable_adjustments
    adjustments.each(&:update_amount)
  end

  def destroy_inapplicable_adjustments
    destroyed = adjustments.reject(&:applicable?).map(&:destroy)
    adjustments.reload if destroyed.any?
  end

  def update_totals!
    calculate_totals
    changes =  {
      :item_total => item_total,
      :adjustment_total => adjustment_total,
      :payment_total => payment_total
    }
    self.class.update_all(changes, { :id => id }) == 1
  end




  def name
    address = bill_address || ship_address
    "#{address.firstname} #{address.lastname}" if address
  end

  # def out_of_stock_items
  #   @out_of_stock_items
  # end
  #
  # def outstanding_balance
  #   [0, total - payments.total].max
  # end
  #
  # def outstanding_balance?
  #   outstanding_balance > 0
  # end
  #
  # def outstanding_credit
  #   [0, payments.total - total].max
  # end
  #
  # def outstanding_credit?
  #   outstanding_credit > 0
  # end

  # def creditcards
  #   creditcard_ids = (payments.from_creditcard + checkout.payments.from_creditcard).map(&:source_id).uniq
  #   Creditcard.scoped(:conditions => {:id => creditcard_ids})
  # end

  # Indicates whether a guest user is associated with the order
  def guest?
    user && user.guest?
  end

  # Associates the order with a registered user (replacing the previously associated guest user)
  #
  # throws an Exception if there is already a registered user associated with the order
  def register!(user)
    raise "Already registred" if user and not user.guest?
    self.user = user and save!
  end

  # Finalizes an in progress order after checkout is complete.  This method is intended to be called automatically by the
  # state machine when the order transitions to the 'complete' state.
  def finalize!
    update_attribute(:completed_at, Time.now)
  end


  # Helper methods for checkout steps

  def available_shipping_methods(display_on = nil)
    return [] unless ship_address
    ShippingMethod.all_available(self, display_on)
  end

  def payment
    payments.first
  end

  def available_payment_methods
    @available_payment_methods ||= PaymentMethod.available(:front_end)
  end

  def payment_method
    if payment and payment.payment_method
      payment.payment_method
    else
      available_payment_methods.first
    end
  end

  def billing_firstname
    bill_address.try(:firstname)
  end

  def billing_lastname
    bill_address.try(:lastname)
  end


  private
  # def complete_order
  #   self.adjustments.each(&:update_amount)
  #   update_attribute(:completed_at, Time.now)
  #
  #   if email
  #     OrderMailer.confirm(self).deliver
  #   end
  #
  #   begin
  #     @out_of_stock_items = InventoryUnit.sell_units(self)
  #     update_totals unless @out_of_stock_items.empty?
  #     shipment.inventory_units = inventory_units
  #     save!
  #   rescue Exception => e
  #     logger.error "Problem saving authorized order: #{e.message}"
  #     logger.error self.to_yaml
  #   end
  # end
  #
  # def cancel_order
  #   make_shipments_pending
  #   restock_inventory
  #   OrderMailer.cancel(self).deliver
  # end
  #
  # def restock_inventory
  #   inventory_units.each do |inventory_unit|
  #     inventory_unit.restock! if inventory_unit.can_restock?
  #   end
  #
  #   inventory_units.reload
  # end
  #
  # def update_line_items
  #   to_wipe = self.line_items.select {|li| 0 == li.quantity || li.quantity.nil? }
  #   LineItem.destroy(to_wipe)
  #   self.line_items -= to_wipe      # important: remove defunct items, avoid a reload
  # end

  def create_user
    self.user ||= User.guest!
  end

  # def create_shipment
  #   self.shipments << Shipment.create(:order => self)
  # end

end
