// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
//= require_tree .
//= require jquery-1.4.2.min
//= require jquery.validate/jquery.validate.min
//= require rails
<%- if additions_for_gemfile.keys.any? { |name| %w{spree spree_core}.include? name.to_s } -%>
//= require store/spree_core
<%- end -%>
