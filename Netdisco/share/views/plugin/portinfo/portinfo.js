 
// create edit icon element just once
var editicon = $("<i id='nd_portinfo-edit-icon' class='icon-edit nd_portinfo-edit-icon'></i>");
editicon.hide();

$(document).ready(function() {
  // need to add all the listeners only once, since they don't go away
  // unless the page is refreshed or changed
  addPortInfoFunctionality();
  $('#nd_search-results').on('click', 'li a',  function() {
    addSavePortInfoButton();
  });
  $('.nd_sidebar').on('submit', '#ports_form', function() {
    addSavePortInfoButton();
  });
  // adds all the custom functionality
  function addPortInfoFunctionality(){
    //make sure that we only do this on the right page
    var queryDict = {}
    location.search.substr(1).split("&").forEach(function(item) {
      queryDict[item.split("=")[0]] = item.split("=")[1]
    });
    // queryDict conveniently taken from http://stackoverflow.com/a/21210643/4961854
    if ((location.pathname.indexOf('/device') === 0 || location.pathname.indexOf('/search') === 0) 
        && queryDict.tab === "ports") {
      var porttable = $('#dp-data-table').DataTable();    
      
      addSavePortInfoButton();
      adjustColumnsOnKeypress();
      makePortInfoFieldsInteractive();
      addBuildingSuggestions();
    }
  }
  function addSavePortInfoButton(){
    // use a mutation observer because we don't know when the data-table will be loaded
    var forEach = Array.prototype.forEach;
    var observer = new MutationObserver(function(mutations) {
      mutations.forEach( function(mutation) {
        if (mutation.addedNodes.length > 0 ) forEach.call (mutation.addedNodes, function(node) {
          if (node.id === "dp-data-table") {
            observer.disconnect();
            
            if (!$('#dp-data-table_submit-port-info').length){
              $('#dp-data-table_filter').after("<button class='btn btn-info' id='dp-data-table_submit-port-info'><i class='icon-save'/> Save Port Info</button>");
              var submitportinfobtn = $('#dp-data-table_submit-port-info');
              submitportinfobtn.prop("disabled", true);
            
              submitportinfobtn.click(function() {
                $('td.nd_portinfo-data-dirty .york-port-info')
                  .get().forEach(function(div) {
                    changeportinfo(div);
                  });
                submitportinfobtn.prop('disabled', true);
              });
            }
          }
        })
      })
    });
      
    observer.observe(document.body, {
      childList: true
      , subtree: true
      , attributes: false
      , characterData: false
    });
  }

  // needed to make port info fields like vanilla netdisco editable fields
  function makePortInfoFieldsInteractive (){
    //var editicon = $('#nd_portinfo-edit-icon');
    
    $('.tab-content').on('mouseover', 'td',
      function(event) {
        if ($(this).children('.york-port-info[contenteditable]').length === 1) {
          editicon.prependTo(this);
          editicon.show();
        }
      }
    );
    $('.tab-content').on('mouseout', 'td',
      function(event) {
        if ($(this).children('.york-port-info[contenteditable]').length === 1) {
          editicon.hide();
        }
      }
    );
    $('.tab-content').on('click', 'td:has(.york-port-info[contenteditable])',
      function(event) {
        var children = $(this).children('.york-port-info[contenteditable]');
        if (children.length) {
          children.focus();
        }
      }
    );

    $('.tab-content').on('focus', '.york-port-info',
      function(event) {
        editicon.hide();
        $(this).closest("td")[0].style.backgroundColor = "#FFFFD3";
      }
    );
    $('.tab-content').on('blur', '.york-port-info',
      function(event) {
        var td = $(this).closest("td");
        td[0].style.backgroundColor = "";
        // more hacks... autosuggest has hidden text for accessibility
        // we save only the data we want, even though it has a performance
        // impact
        // we do this so we can have sorting on current values in columns
        $('#dp-data-table').DataTable().cell(td).data(this.outerHTML);
      }
    );
    
    // activity for contenteditable control
    $('.tab-content').on('keydown', '.york-port-info[contenteditable=true]', function(event) {
      var div = this,
        td = $(div).closest('td'),
        esc = event.which == 27,
        nl = event.which == 13;

      if (esc) {
        $(div).blur();
      } else if (nl) {
        // stop the event from bubbling to the default netdisco event handler
        event.stopPropagation();
        event.preventDefault();

        changeportinfo(div);
        $(div).blur();
      } else {
        // save the original to revert to and compare against
        if (this.dataset.original === undefined) {
          this.dataset.original = $(div).text();
        } else {
          // save attr to td to proper css appearance
          td[0].title = "This change has not been saved.";
          td.addClass("nd_portinfo-data-dirty");
          
          $('#dp-data-table_submit-port-info').prop("disabled", false);
        }
      }
    });
  }

  function addBuildingSuggestions() {
    // Modify building suggestions on blur
    $('.tab-content').on('blur', 'div.york-port-info[contenteditable=true][data-column=building]',
      function(event) {
        var t = $(event.target);
        var building = t.text().trim();
        if (building != "") {
          var index = buildingSuggestions.indexOf(building);
          if (index >= 0) {
            buildingSuggestions.splice(index, 1);
          }
          buildingSuggestions.unshift(building);
        }
      });

    // Add a building dropdown
    // Suggestions initially ordered alphabetically and
    // re-ordered with the most recent item at the top when an item is selected
    $.ajax('/ajax/plugin/buildings', {
      dataType: "json",
      success: function(data) {
        buildingSuggestions = data;

        // add autocomplete functionality when field recieves focus
        $('.tab-content').on('focus', '[data-column=building]', function() {
          $(this).autocomplete({
            source: function(request, response) {
              var suggest = [];
              var size = 0;
              var max = 5;
              for (var i = 0, l = buildingSuggestions.length; i < l && size < max; i++) {
                if (buildingSuggestions[i].toLowerCase()
                  .indexOf(request.term.toLowerCase()) >= 0) {
                  suggest.push(buildingSuggestions[i]);
                  size++;
                }
              }
              response(suggest);
            },
            delay: 50,
            minLength: 0
          });
        });
      }
    });
  }
  
  // make a call to change the port info for a port
  function changeportinfo(e) {
    var div = $(e);
    var td = div.closest('td');

    $.ajax({
      type: 'GET',
      url: uri_base + '/ajax/portinfocontrol',
      data: {
        device: div.data('for-device'),
        port: div.data('for-port'),
        column: div.data('column'),
        value: div.text()
      },
      success: function() {
        td[0].title = "";
        td.removeClass("nd_portinfo-data-dirty");
        td.animate({
            backgroundColor: "#AFA"
          }, 100)
          .delay(500)
          .animate({
            backgroundColor: "#FFF"
          }, 700);
        div[0].dataset.original = div.text();
      },
      error: function() {
        toastr.error('Failed to submit change request');
        div.blur();
      }
    });
  }
  
  var navBuildingSuggestions;
  // Port search by location functionality
  $.ajax('/ajax/plugin/buildings', {
    dataType: "json",
    success: function(data) {
      navBuildingSuggestions = data;


      var input = $('#port-building-input');
      input.autocomplete({
        source: function(request, response) {
          var suggest = [];
          var size = 0;
          for (var i = 0, l = navBuildingSuggestions.length; i < l; i++) {
            if (navBuildingSuggestions[i].toLowerCase()
              .indexOf(request.term.toLowerCase()) >= 0) {
              suggest.push(navBuildingSuggestions[i]);
              size++;
            }
          }
          response(suggest);
        },
        select: function() {
          $('.nd_location-port-search-additional').slideDown();
        },
        appendTo: "#nd_location-port-search",
        minLength: 0,
        delay: 50
      });
      input.focus(function(){
        // bring up the list of suggestions if clicking building field for the first time
        if (!input.val()){
          input.autocomplete("search", "");
        }
      });
    }
  });

  /* adjust columns on keypress because datatables does not
  automatically adjust columns on edit */
  function adjustColumnsOnKeypress() {
    $('.tab-content').on('keypress', '#dp-data-table',
      debounce(function(){
        $('#dp-data-table').DataTable().columns.adjust();
      }, 250)
    );
  };

  /* Search ports by building functionality */
  $('#port-building-input').on('blur focus', function(){
    if ($(this).val()){
      $('.nd_location-port-search-additional').slideDown();
    } else {
      $('.nd_location-port-search-additional').slideUp();
    }
  });

  if ($('.nd_location-port-search-additional input')
        .filter(function(){ return this.value.length>0; }).length > 0){
    $('#port-building-input')
      .after("<div class='port-building-form-reset' rel='tooltip' data-placement='right'"
        + " title='Reset search form'>Reset</div>");
    $('.port-building-form-reset').tooltip();
    $('.port-building-form-reset').click(function(){
       $('#port-building-input').focus();
       $('.nd_location-port-search-additional').slideDown();
       $('#nd_location-port-search form input:visible').val('');
       $('.port-building-form-reset').mouseout().remove();
    });
  }
  
  $('#nd_location-port-search form').keypress(function(e){
    if ($('#port-building-input').val()){
      // enter pressed
      if (e.keyCode == 13) {
        this.submit();
      // tab pressed
      } else if (e.keyCode == 9){
        $('.nd_location-port-search-additional').slideDown();
      }
    }
  });
  $('.location-port-search-close-btn').click(function(){
     $('.nd_location-port-search-additional').slideUp();
  });
});
