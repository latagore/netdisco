
// York cable data javascript

var queryDict;
function loadParameterDictionary(){
  queryDict = {};
  location.search.substr(1).split("&").forEach(function(item) {
    queryDict[item.split("=")[0]] = item.split("=")[1]
  });
  // queryDict conveniently taken from http://stackoverflow.com/a/21210643/4961854
}

function disableTabsOnAdvancedPortSearch(){
  
  $('body').on('click', '.nav-tabs li[disabled]', function(event) {
    event.preventDefault();
  });
  $('.nd_sidebar-form').submit(function(){
    if (this.id === "ports_form" && queryDict['q'] === ""){
      $('.nav-tabs li:not(.active) a')
        .contents()
        .filter(function() {
          return this.nodeType === 3; //Node.TEXT_NODE
          // use magic number 3 because IE 7 doesn't define Node global
        })
        .each(function(i, element){
          var li = $(element).closest('li');
          li.append(element);
          li.children('a').remove();
          li.attr('disabled', true);
        });
    }
  });
}


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
function addPortInfoInteractiveListeners (){
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
  $('.tab-content').on('click', 'td',
    function(event) {
      var children = $(this).children('.york-port-info[contenteditable]');
      if (children.length) {
        children.focus();
      }
    }
  );
   
  $('.tab-content').on('focus', '.york-port-info',
    function(event) {
      // adjust columns on focusing building cell
      if (this.dataset.column === 'building'){
        // $('#dp-data-table').DataTable().columns.adjust();
      }
      editicon.hide();
      $(this).closest("td")[0].style.backgroundColor = "#FFFFD3";
    }
  );
  $('.tab-content').on('blur', '.york-port-info',
    function(event) {
      // adjust columns on focusing building cell
      if (this.dataset.column === 'building'){
        $('#dp-data-table').DataTable().columns.adjust();
      }
      
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
    }
  });
  
  $('.tab-content').on('input', '.york-port-info[contenteditable=true]', function(event) {
    var div = this,
        td = $(div).closest('td');
    
    if (typeof this.dataset.original === 'undefined'
        || this.dataset.original !== $(div).text()){
      // save attr to td to proper css appearance
      td[0].title = "This change has not been saved.";
      td.addClass("nd_portinfo-data-dirty");
 
      $('#dp-data-table_submit-port-info').prop("disabled", false);
    }

    // save the original to revert to and compare against
    if (this.dataset.original === undefined) {
      this.dataset.original = $(div).text();
    }
  });
  /* adjust columns on keypress because datatables does not
  automatically adjust columns on edit */
  $('.tab-content').on('input', '#dp-data-table',
    debounce(function(){
      $('#dp-data-table').DataTable().columns.adjust();
    }, 500)
  );
  
  /* take to the top when hitting "Update View" */
  $('#ports_submit').click(function(){
    $("html, body").animate({ scrollTop: 0 }, 2000, 'easeInOutQuart' );
  });
}
function addBuildingSuggestionsToPortsTable() {
  var buildings;
  // Add a building dropdown
  // Suggestions initially ordered alphabetically and
  // re-ordered with the most recent item at the top when an item is selected

  $('.tab-content').on('focus', '[data-column=building]', function() {
    $(this).autocomplete({
      source: buildingAutocompleteSource,
      minLength: 0,
      delay: 200
    });
  });
}

function addBuildingSuggestionsToPortsSidebar() {
  // add autocomplete to building search on sidebar
  $('#ports_form #nd_building-query').focus(function() {
    if (!$(this).data('buildingAutocomplete')) {
      $(this).autocomplete({
        source: buildingAutocompleteSource,
        minLength: 0,
        delay: 200
      });
    }
  });
}

function enableCSVUpload(){
  // only show upload icon when ports tab shown
  $('.nd_sidebar-form').submit(function(){
    if (this.id === "ports_form"){
      $('#nd_csv-upload-icon').show();
    } else {
      $('#nd_csv-upload-icon').hide();
    }
  });

  $('#nd_csv-upload-icon').click(function() {
    $('#nd_csv-upload-modal').show();
  });
  
  $('#nd_csv-upload-modal-cancel, .nd_csv-upload-modal-close').click(function() {
    $('#nd_csv-upload-modal').hide();
    $('#nd_csv-upload-modal-body-success').hide();
    $('#nd_csv-upload-modal-body-error').hide();
    $('#nd_csv-upload-modal-body-input').show();
    $('#nd_csv-upload-modal form').trigger('reset');
  });
  
  // replace submit with ajax submit
  $('#nd_csv-upload-form').submit(function(e) {
    e.preventDefault();
    e.stopPropagation();
    $('#nd_csv-upload-modal-body-input').hide();
    $('#nd_csv-upload-modal-body-loading').show();
    var form = $('#nd_csv-upload-form');
    var formData = new FormData(form.get(0));

    $.ajax(form.attr("action"), {
      data: formData,
      method: "POST",
      processData: false,
      contentType: false,
      success: function(data) {
        var uploadWarnings = $('.upload-warnings');
        uploadWarnings.empty();

        if (data && data.warnings && data.warnings.length){
          var warningBegin = document.createElement("strong");
          warningBegin.appendChild(document.createTextNode("Warning: "));
          uploadWarnings.append(warningBegin);

          var ul = document.createElement("ul");
          ul = $(ul);
          data.warnings.forEach(function(val){
            var warn = document.createElement("li");
            warn.appendChild(document.createTextNode(val));
            ul.append(warn);
          });
          uploadWarnings.append(ul);
        }
        
        $('#nd_csv-upload-modal-body-loading').hide();
        $('#nd_csv-upload-modal-body-success').show();
      },
      error: function(xhr, status, errorThrown) {
        var data = JSON.parse(xhr.responseText);
        var uploadWarnings = $('.upload-warnings');
        uploadWarnings.empty();
        uploadWarnings.hide();
        var uploadErrors = $('.upload-errors');
        uploadErrors.empty();
        uploadErrors.hide();

        if (data && data.errors && data.errors.length){
          var errorBegin = document.createElement("strong");
          errorBegin.appendChild(document.createTextNode("Error, upload cancelled: "));
          uploadErrors.append(errorBegin);
          
          var ul = document.createElement("ul");
          ul = $(ul);
          data.errors.forEach(function(val){
            var error = document.createElement("li");
            error.appendChild(document.createTextNode(val));
            ul.append(error);
          });
          uploadErrors.append(ul);
          uploadErrors.show();
        } else {
          uploadErrors.append(document.createTextNode("Error, contact your site administrator."));
          uploadErrors.show();
        }

        if (data && data.warnings && data.warnings.length){
          var warningBegin = document.createElement("strong");
          warningBegin.appendChild(document.createTextNode("Warning: "));
          uploadWarnings.append(warningBegin);

          var ul = document.createElement("ul");
          ul = $(ul);
          data.warnings.forEach(function(val){
            var warn = document.createElement("li");
            warn.appendChild(document.createTextNode(val));
            ul.append(warn);
          });
          uploadWarnings.append(ul);
          uploadWarnings.show();
        }
        
        $('#nd_csv-upload-modal-body-loading').hide();
        $('#nd_csv-upload-modal-body-error').show();
        
      }
    });
    $('#nd_csv-upload-modal form').trigger('reset');
  });
}


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
    // use regexs for fast testing
    var br = new RegExp('^' + request.term, 'i');  // matches strings that begin with term
    var wr = new RegExp('\\b' + request.term, 'i');  // matches strings that have a word beginning term
    var r  = new RegExp(request.term, 'i'); // matches anywhere in the string
    
    var suggests = []; // suggestions
    var possible = buildings.slice(); // remaining possibilities for building matches 
    
    var regexOrder = [br, wr, r];
    var nameTypeOrder =  ['official', 'short', 'uit', 'other', 'buildingNumber' ];
    
    // cache array lengths for crappy performance on firefox
    var tl = nameTypeOrder.length;
    var rl = regexOrder.length;
    var pl = possible.length;
    
    for (var i = 0; i < tl; i++){
      var nameType = nameTypeOrder[i];
      for (var j = 0; j < rl; j++){
        var regex = regexOrder[j];
        for (var k = 0; k < pl; k++){
          var b = possible[k];
          var suggest = {
            label: b.label,
            labelType: b.labelType,
            buildingNumber: b.buildingNumber
          };
          
          if (!b[nameType]){
            continue;
          }
          
          if (nameType === "other") {
            for (var l = 0, ol = b.other.length; l < ol; l++){
              var other = b.other[l];
              if (regex.test(other)) {
                suggest.matchingName = other;
                suggest.matchingNameType = "OTHER";
                suggests.push(suggest);
                break;
              }
            }
          } else if (nameType === "buildingNumber") {
            if (regex.test(b[nameType])){
              
              suggest.matchingName = b[nameType];
              suggest.matchingNameType = "BUILDING_NUMBER";
              suggests.push(suggest);
            }
          } else {      
            if (regex.test(b[nameType])){
              suggest.matchingName = b[nameType];
              suggest.matchingNameType = nameType.toUpperCase();
              suggests.push(suggest);
            }
          }
          // if the nameType matched a building, remove it from possibilities
          if (suggest.matchingNameType){
            possible.splice(k, 1);
            k = k - 1;
            pl = pl - 1;
          }
        }
      }
    }
    response(suggests);
  }

// add the various features to the page
function addNavBarFunctionality(){
  var input = $('#port-building-input');
  $('#advanced-port-search-btn').click(function(){
    if ($('.nd_location-port-search-additional:visible').length){
      $('.nd_location-port-search-additional').slideUp();
    } else {
      $('.nd_location-port-search-additional').slideDown();
    }
  });
  
  // auto complete functionality for advanced ports search 
  input.autocomplete({
    source: buildingAutocompleteSource,
    appendTo: ".nd_location-port-search-additional",
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

  $('#nd_location-port-search form').submit(function(e){
    var ok = true;
    if ($('#cable-input').val() !== ""
          || $('#pigtail-input').val() !== ""){

      // check that there is at least another field 
      if ($('input:visible:not(#cable-input,#pigtail-input)')
            .filter(function(){ return this.value.length>0; }).length === 0){
        ok = false;
        
      }
    }
  });
  var warned = false;
  var dependsFired = false;
  $('#nd_location-port-search form').validate({
    rules: {
      building: {
        required: {
          "depends": function(element) {
            if (!dependsFired){
              dependsFired = true;
              return $("#pigtail-input:filled, #cable-input:filled").length && !warned;
            } else {
              return $("#pigtail-input:filled, #cable-input:filled").length;
            }
          }
        }
      }
    }, 
    messages: {
      building: "The building field is recommended when searching for pigtail or horizontal cable. Press Enter to search anyways.",
    },
    invalidHandler: function(event, validator){
      warned = true;
    },
    errorPlacement: function(error, element){
      element.before(error);
    },
    focusInvalid: false
  });
  
  $('#nd_location-port-search form').keypress(function(e){
    dependsFired = false;
    if (e.keyCode === 13) {
      $(this).submit();
    } else {
      warned = false;
    }
  });
  $('.location-port-search-close-btn').click(function(){
     $('.nd_location-port-search-additional').slideUp();
  });
  
}
function addPortInfoFunctionality(){
  $('#nd_search-results').on('click', 'li a',  function() {
    addPortInfoInteractiveListeners();
    addSavePortInfoButton();
    addBuildingSuggestionsToPortsTable();
  });
  $('.nd_sidebar').on('submit', '#ports_form', function() {
    addSavePortInfoButton();
  });
  
  //make sure that we only do this on the right page
  if ((location.pathname.indexOf('/device') === 0 || location.pathname.indexOf('/search') === 0)
      && queryDict.tab === "ports") {
    var porttable = $('#dp-data-table').DataTable();

    addPortInfoInteractiveListeners();
    addSavePortInfoButton();
    addBuildingSuggestionsToPortsTable();
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
  loadParameterDictionary();
  disableTabsOnAdvancedPortSearch();
  addPortInfoFunctionality();
  addNavBarFunctionality();
  enableCSVUpload();
});
