require 'rubygems'
require 'spork'

Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However,
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.

  ENV["RAILS_ENV"] = "test"    
  #RAILS3 TODO
  require File.expand_path('../../config/environment', __FILE__)
  require 'rails'
  require 'rails/test_help'  
  require 'factory_girl'
  #require 'authlogic/test_case'
  factories_path = File.expand_path('../factories', __FILE__)
  models_in_core_path = File.expand_path('../../app/models', __FILE__)
  Dir[models_in_core_path+"/*.rb",  factories_path+"/*.rb"].each {|file| require file }
  #require "authlogic/test_case"
  #RAILS3 TODO
  #require File.expand_path(File.dirname(__FILE__) + "/../vendor/extensions/payment_gateway/test/mocks/authorize_net_cim_mock")

  # BENCHMARK=[true|full] to use test_benchmark
  require 'test_benchmark' if ENV["BENCHMARK"]

  class ActiveSupport::TestCase
    #RAILS3 TODO
    #self.use_transactional_fixtures = true
    #self.use_instantiated_fixtures  = false
  end

  I18n.locale = "en"
  #Spree::Config.set(:default_country_id => Country.first.id) if Country.first

  class ActionController::TestCase
    #setup :activate_authlogic
  end

  #ActionController::TestCase.class_eval do
    ## special overload methods for "global"/nested params
    #[ :get, :post, :put, :delete ].each do |overloaded_method|
      #define_method overloaded_method do |*args|
        #action,params,extras = *args
        #super action, params || {}, *extras unless @params
        #super action, @params.merge( params || {} ), *extras if @params
      #end
    #end
  #end

  def setup
    super
    @params = {}
  end

  class TestCouponCalc
    def self.calculate_discount(checkout)
      0.99
    end
  end

  Zone.class_eval do
    def self.global
      find_by_name("GlobalZone") || Factory(:global_zone)
    end
  end

  def create_complete_order
    @zone = Zone.global
    @order = Factory(:order)
    3.times do
      #variant = Factory(:product).variants.first
      variant = Factory(:variant)
      Factory(:line_item, :variant => variant, :order => @order)
    end

    @shipping_method = ShippingMethod.new(:name => 'fedex')
    @checkout = @order.checkout
    @checkout.email = Faker::Internet.email
    @checkout.ship_address = Factory(:address)
    @checkout.shipping_method = @shipping_method

    @calculator = Calculator::FlexiRate.new
    @shipping_method.calculator = @calculator

    @checkout.save

    @shipment = @order.shipment

    @checkout.bill_address = Factory(:address)

    unless @zone.include?(@order.shipment.address)
      ZoneMember.create(:zone => Zone.global, :zoneable => @checkout.ship_address.country)
      @zone.reload
    end

    @checkout.save
    @shipment.save
    @order.save
    @order.reload
    @order.save
    @order
  end

# Sets up an order with state 'new' with completed checkout and authorized payment
  def create_new_order
    create_complete_order
    @checkout.next!
    @checkout.next!
    @checkout.creditcard_attributes = Factory.attributes_for(:creditcard)
    @checkout.next!
  end

  def create_new_order_v2
    create_complete_order
    @checkout.payments = [Factory(:payment)]
    @checkout.state = "complete"
    @checkout.save
    @order.complete!
  end
  
  def create_paid_order
    create_complete_order
    @order.payments = [Factory(:payment, :amount => @order.total, :payable => @order)]
    until @order.checkout.complete?
      @order.checkout.next!
    end
    @order.payments.first.finalize!
    @order.reload
    @order.pay!
  end

# useful method for functional tests that require an authenticated user
  def set_current_user
    @user = Factory(:user)
    @controller.stub!(:current_user, :return => @user)
  end

  def sort_list_hash(thing)
    thing.map(&:sort).sort
  end
  def assert_equal_list_hash(alpha,beta)
    assert_equal(sort_list_hash(alpha), sort_list_hash(beta))
  end
end

Spork.each_run do
  # This code will be run each time you run your specs.

end
