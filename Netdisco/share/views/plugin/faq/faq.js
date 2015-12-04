$(document).ready(function(){
  // allows FAQ answers to be opened and closed
  $('#nd_home-help h4')
    .click(function(){
      $(this).parent().next(".answer").slideToggle();
    });
});
