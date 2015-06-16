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

$('div.york-port-info').on('blur', '[contenteditable=true]', function (event) {
    if (dirty) {
        document.execCommand('undo');
        dirty = false;
        $(this).blur();
    }
});
});
