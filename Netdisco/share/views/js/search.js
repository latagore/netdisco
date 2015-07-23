  // used by the tabbing interface to make sure the correct
  // ajax content is loaded
  var path = 'search';

  // fields in the Search Options form 
  var form_inputs = $("#device_form .clearfix input, #ports_form .clearfix input")
      .not('[type="checkbox"]')
      .add("#device_form .clearfix select");

  // this is called by do_search to support local code
  // which might need to act on the newly inserted content
  // but which cannot use jQuery delegation via .on()
  function inner_view_processing(tab) {
    
    // LT wanted the page title to reflect what's on the page :)
    document.title = $('#nq').val()
      +' - Search '+ $('#'+ tab + '_link').text() + "s - Netdisco";

    // used for contenteditable cells to find out whether the user has made
    // changes, and only reset when they submit or cancel the change
    var dirty = false;

    // show the reset button if ports tab selected
    if (tab === 'ports'){
      $('#nd_sidebar-reset-link').show();
    } else {
      $('#nd_sidebar-reset-link').hide();
    }

    // activate modals, tooltips and popovers
    $('.nd_modal').modal({show: false});
    $("[rel=tooltip]").tooltip({live: true});
    $("[rel=popover]").popover({live: true});
  }

  // on load, establish global delegations for now and future
  $(document).ready(function() {
    var tab = '[% tab.tag %]'
    var target = '#' + tab + '_pane';

    // sidebar form fields should change colour and have bin/copy icon
    form_inputs.each(function() {device_form_state($(this))});
    form_inputs.change(function() {device_form_state($(this))});

    // sidebar collapser events trigger change of up/down arrow
    $('.collapse').on('show', function() {
      $(this).siblings().find('.nd_arrow-up-down-right')
        .toggleClass('icon-chevron-up icon-chevron-down');
    });

    $('.collapse').on('hide', function() {
      $(this).siblings().find('.nd_arrow-up-down-right')
        .toggleClass('icon-chevron-up icon-chevron-down');
    });

    // if the user edits the filter box, revert to automagical search
    $('#ports_form').on('input', "input[name=f]", function() {
      $('#nd_ports-form-prefer-field').attr('value', '');
    });


    // handler for copy icon in search option
    $('.nd_field-copy-icon').click(function() {
      var name = $(this).data('btn-for');
      var input = $('#device_form [name=' + name + ']');
      input.val( $('#nq').val() );
      device_form_state(input); // will hide copy icons
    });

    // handler for bin icon in search option
    $('.nd_field-clear-icon').click(function() {
      var name = $(this).data('btn-for');
      var input = $('#device_form [name=' + name + ']');
      input.val('');
      device_form_state(input); // will hide copy icons
    });

    // allow port filter to have a preference for port/name/vlan
    $('#ports_form').on('click', '.nd_device-port-submit-prefer', function() {
      event.preventDefault();
      $('#nd_ports-form-prefer-field').attr('value', $(this).data('prefer'));
      $(this).parents('form').submit();
    });
    
    // clickable device port names can simply resubmit AJAX rather than
    // fetch the whole page again.
    // only applies to aggregate link master ports, since it's pointless
    // otherwise
    /*$('#ports_pane').on('click', 'a.nd_this-port-only', function(event) {
      event.preventDefault(); // link is real so prevent page submit

      var port = $(this).text();
      port = $.trim(port);
      portfilter.val(port);
      $('.nd_field-clear-icon').show();

      // make sure we're preferring a port filter
      $('#nd_ports-form-prefer-field').attr('value', 'port');

      $('#ports_form').trigger('submit');
      device_form_state(portfilter); // will hide copy icons
    });*/

    // VLANs column list collapser trigger
    // it's a bit of a faff because we can't easily use Bootstrap's collapser
    $('#ports_pane').on('click', '.nd_collapse-vlans', function() {
        $(this).siblings('.nd_collapsing').toggle();
        if ($(this).find('.nd_arrow-up-down-left').hasClass('icon-chevron-up')) {
          $(this).html('<div class="nd_arrow-up-down-left icon-chevron-down icon-large"></div>Hide VLANs');
        }
        else {
          $(this).html('<div class="nd_arrow-up-down-left icon-chevron-up icon-large"></div>Show VLANs');
        }
    });


  });
