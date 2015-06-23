// Add focus and hover appearance
$(document).ready(function (){
$('.tab-content').on('mouseenter', 'td:has(div.york-port-info[contenteditable=true])',
  function(event) {
    $(this).prepend("<i class='icon-edit nd_portinfo-edit-icon'></i>");
  }
);
$('.tab-content').on('mouseleave', 'td:has(div.york-port-info)', 
  function(event) {
    $(".nd_portinfo-edit-icon").remove();
  }
);
$('.tab-content').on('click', 'td:has(div.york-port-info[contenteditable=true])', 
  function(event) {
      var div = $(this).children(".york-port-info");
      div.focus();
  }
);

$('.tab-content').on('focus', '.york-port-info',
  function(event) {
    $(".nd_portinfo-edit-icon").remove();
    $(this).closest("td")[0].style.backgroundColor="#FFFFD3";
  }
);
$('.tab-content').on('blur', '.york-port-info',
  function(event) {
    $(this).closest("td")[0].style.backgroundColor="";
  }
);
});

// ask for changes with AJAX
var porttable = $('#dp-data-table').DataTable();
function changeportinfo (e) {
  var div = $(e);
  
  $.ajax({
    type: 'GET'
    ,url: uri_base + '/ajax/portinfocontrol'
    ,data: {
      device:  div.data('for-device')
      ,port:   div.data('for-port')
      ,column: div.data('column')
      ,value: div.text()
    }
    ,success: function() {
      toastr.info('Submitted change request');
    }
    ,error: function() {
      toastr.error('Failed to submit change request');
      div.text(td.data('default'));
      div.blur();
    }
  });
};

var pdirty = false; // is port_info_dirty?

// activity for contenteditable control
$(document).ready(function() {
$('.tab-content').on('keydown', '.york-port-info[contenteditable=true]', function (event) {
    var cell = this,
        td = $(cell).closest('td'),
        esc = event.which == 27,
        nl = event.which == 13;

    if (esc) {
        $(cell).blur();
    } else if (nl) {
        event.stopPropagation();
        event.preventDefault();
        
        changeportinfo(cell);

        pdirty = false;
        $(cell).blur();
    } else {
        pdirty = true;
    }
});

$('.tab-content').on('blur', 'div.york-port-info[contenteditable=true]', function (event) {
    if (pdirty) {
        document.execCommand('undo');
        pdirty = false;
        $(this).blur();
    }
});

// Add a building dropdown
// Suggestions initially ordered alphabetically and
// re-ordered with the most recent item at the top when an item is selected
$.ajax('/ajax/plugin/buildings', {
  dataType: "json",
  success: function(data){
    buildingSuggestions = data;
    console.log("buildings loaded");    

    // add autocomplete functionality when field recieves focus
    $('.tab-content').on('focus', '[data-column=building]', function(){
      $(this).autocomplete({
        source: function(request, response){
          var suggest = [];
          for (var i = 0, l = buildingSuggestions.length; i < l; i++){
            if (buildingSuggestions[i].toLowerCase()
               .indexOf(request.term.toLowerCase()) >= 0){
              suggest.push(buildingSuggestions[i]);
            }
          }
          response(suggest);
        }
      });
    });
  }
});
});
