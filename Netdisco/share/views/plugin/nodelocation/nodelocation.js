$(document).ready(function() {
  $('#nodelocation_form').submit( function (event) {
    // override the default submit handler in do_search because it won't send post data...
    
    
    var tab = 'nodelocation'
    var target = '#' + tab + '_pane';
    event.stopImmediatePropagation();
    event.preventDefault();
    
    // cancel the last search request, then issue the new one
    if (search_xhr) {
      search_xhr.abort();
    }
    
    // in case of slow data load, let the user know
    $(target).html(
      '<div class="span2 alert"><i class="icon-spinner icon-spin"></i> Waiting for results...</div>'
    );

    var formData = new FormData($('#nodelocation_form')[0]);
    
    // submit the query and put results into the tab pane
    search_xhr = $.ajax( uri_base + '/ajax/content/report/nodelocation',
      {
        timeout: 55000,
        error: function(xhr, status, errorThrown){
          if (status === "timeout") {
            $(target).html(
              '<div class="span5 alert alert-error"><i class="icon-warning-sign"></i> ' +
              'Search timed out! Reduce the size of your search by filtering on additional criteria or contact your site administrator.</div>'
            );
          } else if (status !== "abort") {
            $(target).html(
              '<div class="span5 alert alert-error"><i class="icon-warning-sign"></i> ' +
              'Search failed! Please contact your site administrator.</div>'
            );
          }
        },
        success: function(response, status, xhr) {
          if (response == "") {
            $(target).html(
              '<div class="span2 alert alert-info">No matching records.</div>'
            );
          } else {
            $(target).html(response);
          }

          // delegate to any [device|search] specific JS code
          $('div.content > div.tab-content table.nd_floatinghead').floatThead({
            scrollingTop: 40
            ,useAbsolutePositioning: false
          });
          inner_view_processing(tab);
        },
        type: 'POST',
        data: formData,
        processData: false,
        contentType: false,
        dataType: "text"
      }
    );
  });
});