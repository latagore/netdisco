var search_xhr;

// parameterised for the active tab - submits search form and injects
// HTML response into the tab pane, or an error/empty-results message
function do_search (event, tab) {
  var form   = '#' + tab + '_form';
  var target = '#' + tab + '_pane';
  var query  = $(form).serialize();

  // stop form from submitting normally
  event.preventDefault();

  // hide or show sidebars depending on previous state,
  // and whether the sidebar contains any content (detected by TT)
  if (has_sidebar[tab] == 0) {
    $('.nd_sidebar, #nd_sidebar-toggle-img-out').hide();
    $('.content').css('margin-right', '10px');
  }
  else {
    if (sidebar_hidden || window.innerWidth < hide_sidebar_width) {
      $('#nd_sidebar-toggle-img-out').show();
    }
    else {
      $('.content').css('margin-right', '215px');
      $('.nd_sidebar').show();
    }
  }

  // in case of slow data load, let the user know
  $(target).html(
    '<div class="span2 alert"><i class="icon-spinner icon-spin"></i> Waiting for results...</div>'
  );

  // cancel the last search request, then issue the new one
  if (search_xhr) {
    search_xhr.abort();
  }

  // submit the query and put results into the tab pane
  search_xhr = $.ajax( uri_base + '/ajax/content/' + path + '/' + tab + '?' + query,
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
      dataType: "text"
    }
  );
}

// keep track of which tabs have a sidebar, for when switching tab
var hide_sidebar_width = 800; // min width before the sidebar is automatically hidden
var has_sidebar = {};
var sidebar_hidden = 0;

// the history.js plugin is great, but fires statechange at pushState
// so we have these semaphpores to help avoid messing the History.

// set true when faking a user click on a tab
var is_from_state_event = 0;
// set true when the history plugin does pushState - to prevent loop
var is_from_history_plugin = 0;

// on tab change, hide previous tab's search form and show new tab's
// search form. also trigger to load the content for the newly active tab.
function update_content(from, to) {
  $('#' + from + '_search').toggleClass('active');
  $('#' + to + '_search').toggleClass('active');

  var to_form = '#' + to + '_form';
  var from_form = '#' + from + '_form';

  // page title
  var pgtitle = 'Netdisco';
  if ($('#nd_device-name').text().length) {
    var pgtitle = $('#nd_device-name').text() +' - '+ $('#'+ to + '_link').text();
  }

  // navbar text decoration special case
  if (to != 'device') {
    $('#nq').css('text-decoration', 'none');
  }
  else {
    form_inputs.each(function() {device_form_state($(this))});
  }

  if (window.History && window.History.enabled && is_from_state_event == 0) {
    is_from_history_plugin = 1;
    window.History.pushState(
      {name: to, fields: $(to_form).serializeArray()},
      pgtitle, uri_base + '/' + path + '?' + $(to_form).serialize()
    );
    is_from_history_plugin = 0;
  }

  $(to_form).trigger("submit");
}

// handler for ajax navigation
if (window.History && window.History.enabled) {
  var History = window.History;
  History.Adapter.bind(window, "statechange", function() {
    if (is_from_history_plugin == 0) {
      is_from_state_event = 1;
      var State = History.getState();
      // History.log(State.data.name, State.title, State.url);
      $('#'+ State.data.name + '_form').deserialize(State.data.fields);
      $('#'+ State.data.name + '_link').click();
      is_from_state_event = 0;
    }
  });
}

// if any field in Search Options has content, highlight in green
function device_form_state(e) {
  var with_val = $.grep(form_inputs,
                        function(n,i) {return($(n).prop('value') != "")}).length;
  var with_text = $.grep(form_inputs.not('select'),
                          function(n,i) {return($(n).val() != "")}).length;

  if (e.prop('value') == "") {
    e.parent(".clearfix").removeClass('success');
    var id = '#' + e.attr('name') + '_clear_btn';
    $(id).hide();

    // if form has no field val, clear strikethough
    if (with_val == 0) {
      $('#nq').css('text-decoration', 'none');
    }

    // for text inputs only, extra formatting
    if (with_text == 0) {
      $('.nd_field-copy-icon').show();
    }
  }
  else {
    e.parent(".clearfix").addClass('success');
    var id = '#' + e.attr('name') + '_clear_btn';
    $(id).show();

    // if form still has any field val, set strikethough
    if (e.parents('form[action="/search"]').length > 0 && with_val != 0) {
      $('#nq').css('text-decoration', 'line-through');
    }

    // if we're text, hide copy icon when we get a val
    if (e.attr('type') == 'text') {
      $('.nd_field-copy-icon').hide();
    }
  }
}

//utility function for views
function capitalizeFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}


// copied from http://stackoverflow.com/a/24004942/4961854
// the above license applies to the debounce function
function debounce(func, wait, immediate) {
  var timeout;           
  return function() {
      var context = this, args = arguments;
      var callNow = immediate && !timeout;

      clearTimeout(timeout);   
      timeout = setTimeout(function() {
           timeout = null;
           if (!immediate) {
             // Call the original function with apply
             // apply lets you define the 'this' object as well as the arguments 
             //    (both captured before setTimeout)
             func.apply(context, args);
           }
      }, wait);
      if (callNow) func.apply(context, args);  
   }; 
};

$(document).ready(function() {
  // hide sidebar on page load if screen too small
  if (window.innerWidth < hide_sidebar_width){
    $('.content').css('margin-right', '10px');
    $('.nd_sidebar').hide();
  }
  
  // sidebar form fields should change colour and have bin/copy icon
  $('.nd_field-copy-icon').hide();
  $('.nd_field-clear-icon').hide();

  // activate jQuery autocomplete on the main search box, for device names only
  var maxSuggestions = 5; // max number of suggestions
  var nq_autocomplete = $('#nq').autocomplete({
    source: function (request, response) {
      $.ajax({ 
        url: uri_base + '/ajax/data/devicename/typeahead', 
        data: { query: request.term }, 
        success: function (data) {
          data.splice(maxSuggestions, Number.MAX_VALUE);
          return response(data); 
        },
        error: function(){
          return response([]); // suggest no data on error
        }
      });
    }
    ,select: function(event, ui) {
      var nq = $('#nq');
      nq.val(ui.item.value);
      nq.closest('form').submit();
    }
    ,minLength: 1
    ,appendTo: "#nq-search"
  }).data("ui-autocomplete");
  
  nq_autocomplete._create = function() {
      nq_autocomplete._super();
      nq_autocomplete.widget().menu( "option", "items", "> :not(.device-suggestion)" );
    };
  nq_autocomplete._renderMenu = function( ul, items ) {
      var that = nq_autocomplete;
      ul.append('<li class="device-suggestion">Devices</li>');
      $.each( items, function( index, item ) {
        var li;
        li = that._renderItem( ul, item );
      });
    };
  // activate tooltips
  $("[rel=tooltip],.has-tooltip").tooltip({live: true});

  // bind submission to the navbar go icon
  $('#navsearchgo').click(function() {
    $('#navsearchgo').parents('form').submit();
  });
  $('.nd_navsearchgo-specific').click(function(event) {
    event.preventDefault();
    if ($('#nq').val()) {
      $(this).parents('form').append(
        $(document.createElement('input')).attr('type', 'hidden')
                                          .attr('name', 'tab')
                                          .attr('value', $(this).data('tab'))
      ).submit();
    }
  });

  // fix green background on search checkboxes
  // https://github.com/twitter/bootstrap/issues/742
  syncCheckBox = function() {
    $(this).parents('.add-on').toggleClass('active', $(this).is(':checked'));
  };
  $('.add-on :checkbox').each(syncCheckBox).click(syncCheckBox);


  // sidebar toggle - trigger in/out on image click()
  $('#nd_sidebar-toggle-img-in').click(function() {
    $('.nd_sidebar').toggle(250);
    $('#nd_sidebar-toggle-img-out').toggle();
    $('.content').css('margin-right', '10px');
    $('div.content > div.tab-content table.nd_floatinghead').floatThead('destroy');
    $('div.content > div.tab-content table.nd_floatinghead').floatThead({
      scrollingTop: 40
      ,useAbsolutePositioning: false
    });
    sidebar_hidden = 1;
  });
  $('#nd_sidebar-toggle-img-out').click(function() {
    $('#nd_sidebar-toggle-img-out').toggle();
    $('.content').css('margin-right', '215px');
    $('div.content > div.tab-content table.nd_floatinghead').floatThead('destroy');
    $('div.content > div.tab-content table.nd_floatinghead').floatThead({
      scrollingTop: 40
      ,useAbsolutePositioning: false
    });
    $('.nd_sidebar').toggle(250);
    sidebar_hidden = 0;
  });

  // could not get twitter bootstrap tabs to behave, so implemented this
  // but warning! will probably not work for dropdowns in tabs
  $('#nd_search-results li').delegate('a', 'click', function(event) {
    event.preventDefault();
    var from_li = $('.nav-tabs').find('> .active').first();
    var to_li = $(this).parent('li')

    from_li.toggleClass('active');
    to_li.toggleClass('active');

    var from_id = from_li.find('a').attr('href');
    var to_id = $(this).attr('href');

    if (from_id == to_id) {
      return;
    }

    $(from_id).toggleClass('active');
    $(to_id).toggleClass('active');

    update_content(
      from_id.replace(/^#/,"").replace(/_pane$/,""),
      to_id.replace(/^#/,"").replace(/_pane$/,"")
    );
  });

  // bootstrap modal mucks about with mouse actions on higher elements
  // so need to bury and raise it when needed
  $('.tab-pane').on('show', '.nd_modal', function () {
    $(this).toggleClass('nd_deep-horizon');
  });
  $('.tab-pane').on('hidden', '.nd_modal', function () {
    $(this).toggleClass('nd_deep-horizon');
  });

  // activate daterange plugin
  $('#daterange').daterangepicker({
    ranges: {
      'Today': [moment(), moment()]
      ,'Yesterday': [moment().subtract('days', 1), moment().subtract('days', 1)]
      ,'Last 7 Days': [moment().subtract('days', 6), moment()]
      ,'Last 30 Days': [moment().subtract('days', 29), moment()]
      ,'This Month': [moment().startOf('month'), moment().endOf('month')]
      ,'Last Month': [moment().subtract('month', 1).startOf('month'), moment().subtract('month', 1).endOf('month')]
    }
    ,minDate: '2004-01-01'
    ,showDropdowns: true
    ,timePicker: false
    ,opens: 'left'
    ,format: 'YYYY-MM-DD'
    ,separator: ' to '
    ,singleDatePicker: true
  }
  ,function(start, end) {
    $('#daterange').trigger('input');
  });

  // handler for datepicker in node sidebar
  $('.nd_sidebar').on('input', '#daterange', function() {
    if ($(this).prop('value') == '') {
      $('#daterange').parent('.clearfix').removeClass('success');
    }
    else {
      $('#daterange').parent('.clearfix').addClass('success');
    }
  });
  $('#daterange').trigger('input');
  
  // dynamically resize data table size
  function resizeTable() {
    var e = $('.tab-content .dataTables_scrollBody');    
    e.height(Math.max(window.innerHeight - 200,300));
  }
  resizeTable();
  $(".dataTable").DataTable().draw();
  
  var d = debounce(resizeTable, 500);
  // resize on datatables init event because fixed columns 
  // plugin isn't robust
  $(document).on("init.dt", resizeTable);
  $(document).on("ajaxComplete", d);
  $(window).on("resize", d);

  // change sidebar selects to use jQuery Chosen plugin
  $('.nd_sidebar select').each(function() {
    var t = $(this);
    t.chosen({
      inherit_select_classes: true,
      placeholder_text_multiple: this.dataset.title,
      search_contains: true,
      disable_search_threshold: 10
    });
    var c = t.next('.chosen-container');
    c.prop("rel", this.rel);
    c.data("title", this.dataset.title);
    c.data("placement", this.dataset.placement);
    // activate tooltips
    $(c).tooltip({live: true});

  });
});
