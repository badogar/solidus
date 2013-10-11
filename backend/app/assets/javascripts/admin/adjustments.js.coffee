$(@).ready( ->
  $('[data-hook=adjustments_new_coupon_code] #add_coupon_code').click ->
    return if $("#coupon_code").val().length == 0
    $.ajax
      type: 'PUT'
      url: Spree.url(Spree.routes.orders_api + '/' + order_number + '/apply_coupon_code.json');
      data:
        coupon_code: $("#coupon_code").val()
      success: ->
        window.location.reload();
      error: (msg) ->
        if msg.responseJSON["error"]
          show_flash_error msg.responseJSON["error"]
        else
          show_flash_error "There was a problem adding this coupon code."
)