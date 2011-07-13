$j(function() { 
  if ($j('#country_based').is(':checked')) {
    show_country();
  } else if ($j('#state_based').is(':checked')) {
    show_state();
  } else {        
    show_zone();
  }
  $j('#country_based').click(function() { show_country();} );
  $j('#state_based').click(function() { show_state();} );
  $j('#zone_based').click(function() { show_zone();} ); 
})   
                                                        
var show_country = function() {
  $j('#state_members :input').each(function() { $(this).prop("disabled", true); })
  $j('#state_members').hide();
  $j('#zone_members :input').each(function() { $(this).prop("disabled", true); })
  $j('#zone_members').hide();
  $j('#country_members :input').each(function() { $(this).prop("disabled", false); })
  $j('#country_members').show();
};

var show_state = function() {
  $j('#country_members :input').each(function() { $(this).prop("disabled", true);
 })
  $j('#country_members').hide();
  $j('#zone_members :input').each(function() { $(this).prop("disabled", true);
 })
  $j('#zone_members').hide();
  $j('#state_members :input').each(function() { $(this).prop("disabled", false); })
  $j('#state_members').show();
};

var show_zone = function() {
  $j('#state_members :input').each(function() { $(this).prop("disabled", true);
 })
  $j('#state_members').hide();
  $j('#country_members :input').each(function() { $(this).prop("disabled", true);
 })
  $j('#country_members').hide();
  $j('#zone_members :input').each(function() { $(this).prop("disabled", false); })
  $j('#zone_members').show();
};

