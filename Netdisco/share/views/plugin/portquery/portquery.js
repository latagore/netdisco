$(document).ready(function(){
  var modalEl = null;   
  $(".tab-content").on('click', '.portQueryBtn', function(){
    // row data from data table
    var rowData = $('#dp-data-table').DataTable().row($(this).closest('tr')).data();
    if (!modalEl) {
      modalEl = $(
      '<div class="modal large hide fade" tabindex="-1" role="dialog">'
      + '  <div class="modal-header">'
      + '    <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>'
      + '    <h3 id="myModalLabel">Port Query</h3>'
      + '  </div>'
      + '  <div class="modal-body">'
      + '    <p><i class="icon-spinner icon-spin icon-large"></i> Loading data...</p>'
      + '  </div>'
      + '  <div class="modal-footer">'
      + '    <button class="btn btn-primary" data-dismiss="modal" aria-hidden="true">Close</button>'
      + '  </div>'
      + '</div>'
      );
      modalEl.appendTo("#dp-data-table");
      modalEl.modal();
      modalEl = modalEl.get(0);
    }
    var modalBody = $(modalEl).find('.modal-body').get(0);
    modalBody.innerHTML='<p><i class="icon-spinner icon-spin icon-large"></i> Loading data...</p>';
    $(modalEl).modal('show');
    
    var url = '[% uri_base %]/ajax/content/portquery'
      + '?device=' + rowData.ip
      + '&port=' + rowData.port;
    $.ajax({
       url: url
    }).done(function(data){
      if (!data){
        modalBody.innerHTML = '<p class="text-warning">Invalid response from device. Try again later.</p>';
        return;
      }
      var content = '<div class="accordion" id="accordion2">'
      + '  <div class="accordion-group">'
      + '    <div class="accordion-heading">'
      + '      <a class="accordion-toggle" data-toggle="collapse" href="#collapseOne">'
      + '        Status'
      + '      </a>'
      + '    </div>'
      + '    <div id="collapseOne" class="collapse in">'
      + '      <div class="accordion-inner portQueryData">'
      + data.status
      + '      </div>'
      + '    </div>'
      + '  </div>'
      + '  <div class="accordion-group">'
      + '    <div class="accordion-heading">'
      + '      <a class="accordion-toggle" data-toggle="collapse" href="#collapseTwo">'
      + '        Disable Reason'
      + '      </a>'
      + '    </div>'
      + '    <div id="collapseTwo" class="collapse">'
      + '      <div class="accordion-inner portQueryData">'
      + data.disablereason
      + '      </div>'
      + '    </div>'
      + '  </div>'
            + '  <div class="accordion-group">'
      + '    <div class="accordion-heading">'
      + '      <a class="accordion-toggle" data-toggle="collapse" href="#collapseThree">'
      + '        Details'
      + '      </a>'
      + '    </div>'
      + '    <div id="collapseThree" class="collapse">'
      + '      <div class="accordion-inner portQueryData">'
      + data.details
      + '      </div>'
      + '    </div>'
      + '  </div>'
            + '  <div class="accordion-group">'
      + '    <div class="accordion-heading">'
      + '      <a class="accordion-toggle" data-toggle="collapse" href="#collapseFour">'
      + '        Configuration'
      + '      </a>'
      + '    </div>'
      + '    <div id="collapseFour" class="collapse">'
      + '      <div class="accordion-inner portQueryData">'
      + data.config
      + '      </div>'
      + '    </div>'
      + '  </div>'
      + '</div>';
      
      modalBody.innerHTML = content;
    });
  });

});