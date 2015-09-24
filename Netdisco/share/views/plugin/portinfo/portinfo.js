// York cable data javascript

// functions that add bits of features to the page
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
function addBuildingSuggestionsToPortTable() {
  var buildings;
  // Add a building dropdown
  // Suggestions initially ordered alphabetically and
  // re-ordered with the most recent item at the top when an item is selected

  $('.tab-content').on('focus', '[data-column=building]', function() {
    if (!$(this).data('buildingAutocomplete')) {
      $(this).autocomplete({
        source: buildingAutocompleteSource,
        minLength: 0,
        delay: 200
      });
    }
  });
}
/* adjust columns on keypress because datatables does not
automatically adjust columns on edit */
function adjustColumnsOnKeypress() {
  $('.tab-content').on('keypress', '#dp-data-table',
    debounce(function(){
      $('#dp-data-table').DataTable().columns.adjust();
    }, 250)
  );
};

// utility functions
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
function setBuildingLabel(b){
  b.buildingNumber = b.campus.charAt(0).toLowerCase() + b.num;
  b.label = b.official ? b.official :
             (b.short ? b.short :
               (b.uit ? b.uit :
                 (b.buildingNumber)
               )
             );
  b.labelType = b.official ? "OFFICIAL" :
                  (b.short ? "SHORT" :
                    (b.uit ? "UIT" :
                      ("BUILDING_NUMBER")
                    )
                  );
}
function buildingAutocompleteSource (request, response) {
    var r = new RegExp(request.term, 'i'); // use regexs for fast testing
    var suggests = [];
    for (var i = 0, l = buildings.length; i < l; i++) {
      var b = buildings[i];
      var suggest = {
        label: b.label,
        labelType: b.labelType,
        buildingNumber: b.buildingNumber
      };

      if (r.test(b.official)) {
        suggest.matchingName = b.official;
        suggest.matchingNameType = "OFFICIAL";
        suggests.push(suggest);
      } else if (r.test(b.short)) {
        suggest.matchingName = b.short;
        suggest.matchingNameType = "SHORT";
        suggests.push(suggest);
      } else if (r.test(b.uit)) {
        suggest.matchingName = b.uit;
        suggest.matchingNameType = "UIT";
        suggests.push(suggest);
      } else if (b.other) {
        for (var j = 0, ol = b.other.length; j < ol; j++){
          var other = b.other[j];
          if (r.test(other)) {
            suggest.matchingName = other;
            suggest.matchingNameType = "OTHER";
            suggests.push(suggest);
            break;
          }
        }
      } else if (r.test(b.buildingNumber)) {
        suggest.matchingName = b.buildingNumber;
        suggest.matchingNameType = "BUILDING_NUMBER";
        suggests.push(suggest);
      }
    }
    response(suggests);
  }

// add the various features to the page
function addBuildingSuggestionsToAdvancedSearch(){
  // auto complete functionality for advanced ports search
  var input = $('#port-building-input');
  input.autocomplete({
    source: buildingAutocompleteSource,
    select: function() {
      $('.nd_location-port-search-additional').slideDown();
    },
    appendTo: "#nd_location-port-search",
    minLength: 0,
    delay: 200
  });
  input.data('buildingAutocomplete').option('showBuildingNumber', true);

  // listeners that provide custom widget feel
  // bring up the list of suggestions if clicking building field for the first time
  input.focus(function(){
    if (!input.val()){
      input.autocomplete("search", "");
    }
  });
  $('#port-building-input').on('blur focus', function(){
    if ($(this).val()){
      $('.nd_location-port-search-additional').slideDown();
    } else {
      $('.nd_location-port-search-additional').slideUp();
    }
  });
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
}
function addPortInfoFunctionality(){
  $('#nd_search-results').on('click', 'li a',  function() {
    addSavePortInfoButton();
  });
  $('.nd_sidebar').on('submit', '#ports_form', function() {
    addSavePortInfoButton();
  });
  
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
    addBuildingSuggestionsToPortTable();
  }
}

// create edit icon element just once
var editicon = $("<i id='nd_portinfo-edit-icon' class='icon-edit nd_portinfo-edit-icon'></i>");
editicon.hide();

var buildings;
$.ajax('/ajax/plugin/buildings', {
  dataType: "json",
  success: function(data) {
    buildings = data.results;
    buildings.forEach(function(b){
      setBuildingLabel(b);
    });

    buildings.sort(function(a,b){
      return a.label < b.label ? -1 : a.label > b.label;
    });
  }
});

// custom autocomplete appearance
$.widget( "building.autocomplete", $.ui.autocomplete, {
  options: {
    showBuildingNumber: false,
    highlightClass: 'nd_suggest-match-highlight'
  },
  _renderItem: function(ul, item){
    var a = document.createElement('a'),
        // regular expression for highlighting the term in the item
        re = new RegExp( "(" + this.term + ")", "i" ),
        cls = this.options.highlightClass
        template = "<span class='"+cls+"'>$1</span>";
    
    // show label
    if (item.matchingNameType === item.labelType){
      var label = document.createElement('span');
      label.innerHTML = item.label.replace(re, template);
      a.appendChild(label);
    } else {
      a.appendChild(document.createTextNode(item.label));
    }
    
    // show building number
    if (this.options.showBuildingNumber){
      var num = document.createElement('span');
      num.setAttribute('class', 'nd_suggest-building-number');
      if (item.matchingNameType === "BUILDING_NUMBER"){
        num.innerHTML = ' (' + item.buildingNumber.replace(re, template) + ')';
      } else {
        num.appendChild(document.createTextNode(' (' + item.buildingNumber + ')'));
      }
      a.appendChild(num);
    }
    
    // show hint that indicates the kind of match if it meets the condition
    if (item.matchingNameType !== item.labelType 
        && !(item.matchingNameType === "BUILDING_NUMBER" && this.options.showBuildingNumber))
    {
      var hint = document.createElement('div');
      hint.setAttribute('class', 'nd_suggest-match');
      hint.innerHTML =  (item.matchingNameType === "OFFICIAL" ? "Official name: " :
                          (item.matchingNameType === "SHORT" ? "Short name: " :
                            (item.matchingNameType === "UIT" ? "UIT name: " :
                              (item.matchingNameType === "OTHER" ? "Alternative name: " :
                                (item.matchingNameType === "BUILDING_NUMBER" ? "Building number: " :
                                  "?"
                                )
                              )
                            )
                          )
                        )
                        + item.matchingName.replace(re, template);
      a.appendChild(hint);
    }
    
    var li = document.createElement('li');
    li.setAttribute('class', 'nd_suggest-item');
    li.appendChild(a);
    // apparently you need to store the item object in the li element
    // even though it's not in the documentation..
    li = $(li).data('ui-autocomplete-item', item);

    // ul is jquery object, append elements differently
    ul.append(li);
    return ul;
  }
});

$(document).ready(function() {
  addPortInfoFunctionality();
  addBuildingSuggestionsToAdvancedSearch();
});
