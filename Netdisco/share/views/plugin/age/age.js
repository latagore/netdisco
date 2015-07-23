$(document).ready(function() {
  if (location.pathname.indexOf('/device') === 0){
    var queryDict = {}
    location.search.substr(1).split("&").forEach(function(item) {queryDict[item.split("=")[0]] = item.split("=")[1]});
    // queryDict conveniently taken from http://stackoverflow.com/a/21210643/4961854
    var ajax = $.ajax(
      '/ajax/deviceage',
      {
        data: {
          device: queryDict.q
        },
        dataType: "json",
        success: function(data){
          var response = JSON.parse(ajax.responseText);

          // days since last discover/macsuck/arpnip
          var discoverAge = parseInt(response.discoverAge);
          var macsuckAge  = parseInt(response.macsuckAge);
          var arpnipAge   = parseInt(response.arpnipAge);
          // limit on entry age in days before a warning is given
          var ageLimit    = parseInt(response.ageLimit);

          var warningMsg = '';

          if (discoverAge >= ageLimit){
            warningMsg += "<p>The last successful discover on this device was " + discoverAge
            + (discoverAge === 1 ? " day" : " days")
            + " ago.</p>"
          } else if (isNaN(discoverAge)) {
            warningMsg += "<p>No discover job has successfully completed on this device.</p>";
          }
          if (macsuckAge >= ageLimit){
            warningMsg += "<p>The last successful macsuck on this device was " + macsuckAge
            + (macsuckAge === 1 ? " day" : " days")
            + " ago.</p>"
          } else if (isNaN(macsuckAge)){
            warningMsg += "<p>No macsuck job has successfully completed on this device.</p>";
          }
          if (arpnipAge >= ageLimit){
            warningMsg += "<p>The last arpnip on this device was " + arpnipAge
            + (arpnipAge === 1 ? " day" : " days")
            + " ago.</p>"
          } else if (isNaN(arpnipAge)){
            warningMsg += "<p>No arpnip job has successfully completed on this device.</p>";
          }

          if (warningMsg !== ''){
            // insert warning message element
            $('.navbar').after(
              '<div class="nd_old-info-warning" title="Hide">'
              + '<h5><strong>Warning - Old Information</strong></h5>'
              + warningMsg
              + '<p><small>Some information may not be reliable. Warnings are given after ' 
              + ageLimit  + (ageLimit === 1 ? ' day' : ' days')
              + '.</small></p>'
              + '</div>');
          }
          
          // add listener to hide the popup
          
          $('.nd_old-info-warning').click(function(){
            // can't slide up on nd_old-info-warning div with CSS display: table, 
            // so we use an inner element workaround instead...
            $(this).slideUp().fadeOut();
          });
                    
        }
      });
  }
});
