#++
# Copyright (c) 2007-2011, Rails Dog LLC and other contributors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#     * Neither the name of the Rails Dog LLC nor the names of its
#       contributors may be used to endorse or promote products derived from this
#       software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#--
require 'rails/all'
require 'rails/generators'
require 'state_machine'
require 'paperclip'
require 'stringex'
require 'kaminari'
require 'nested_set'
require 'acts_as_list'
require 'resource_controller'
require 'active_merchant'
require 'meta_search'
require 'find_by_param'
require 'jquery-rails'

require 'spree/core/ext/active_record'
require 'spree/core/ext/hash'

require 'spree/core/delegate_belongs_to'

require 'spree/core/theme_support'
require 'spree/core/spree_custom_responder'
require 'spree/core/spree_respond_with'
require 'spree/core/ssl_requirement'
require 'spree/core/preferences/model_hooks'
require 'spree/core/preferences/preference_definition'
require 'spree/core/controller_helpers'
require 'spree/store_helpers'
require 'spree/file_utilz'
require 'spree/calculated_adjustments'
require 'spree/current_order'
require 'spree/preference_access'
require 'spree/config'
require 'spree/mail_settings'
require 'spree/mail_interceptor'
require 'spree/redirect_legacy_product_url'
require 'spree/middleware/seo_assist'

silence_warnings do
  require 'spree/core/authorize_net_cim_hack'
end

require 'spree/core/version'

require 'spree/core/engine'
require 'generators/spree/site/site_generator'
require 'generators/spree/dummy/dummy_generator'
require 'generators/spree/sandbox/sandbox_generator'

ActiveRecord::Base.class_eval do
  include Spree::CalculatedAdjustments
  include CollectiveIdea::Acts::NestedSet
end

if defined?(ActionView)
  require 'nested_set/helper'
  ActionView::Base.class_eval do
    include CollectiveIdea::Acts::NestedSet::Helper
  end
end

ActiveSupport.on_load(:action_view) do
  include StoreHelpers
end

module SpreeCore
  
end
