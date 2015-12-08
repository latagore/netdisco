$(document).ready(function(){
  // allows FAQ answers to be opened and closed
  $('#nd_home-help h4')
    .click(function(){
      $(this).parent().next(".answer").slideToggle();
    });

  // documentation answers might get cut off. need to allow
  // overflow for all answers to display.
  $('#nd_user-doc-container').on('shown', function(){
    $(this).css({'overflow': 'visible'});
  });
  $('#nd_user-doc-container').on('hide', function(){
    $(this).css({'overflow': 'hidden'});
  });
  
  $('.doc-link').click(function(){
    $(this).closest('div').fadeOut();
    $(document.getElementById($(this).data('topic')))
      .click();
  });
  

  // display documentation on click
  $('.sidebar-bg a').click(function(e){
  
    var tr = $(this).closest('tr');
    var index = tr.index();
    var y = tr.position().top;
    var duration = 300;
    
    var tip =  $('#nd_user-instructions-tip');
    if (tip.is(':visible')){
      tip.fadeOut(duration);
    
      $('#nd_user-instructions > div')
        .eq(index)
        .delay(duration)
        .fadeIn(duration)
        .css({
          top: (y) + "px"
        });
    } else {
      if ($('#nd_user-instructions > div:visible').index() == index){
        $('#nd_user-instructions > div')
          .fadeOut(duration);
      } else {
        $('#nd_user-instructions > div')
          .fadeOut(duration)
          .eq(index)
          .delay(duration)
          .fadeIn(duration)
          .css({
            top: (y) + "px"
          });
      } 
    }
  });;
});
