    // sidebar toggle
    $('#sidebar_toggle_img_in').click(
      function() {
        $('.sidebar').toggle(
          function() {
            $('#sidebar_toggle_img_out').toggle();
            $('.nd_content').animate({'margin-left': '5px !important'}, 100);
            $('.device_label_right').toggle();
          }
        );
      }
    );
    $('#sidebar_toggle_img_out').click(
      function() {
        $('#sidebar_toggle_img_out').toggle();
        $('.nd_content').animate({'margin-left': '225px !important'}, 200,
          function() {
            $('.device_label_right').toggle();
            $('.sidebar').toggle(200);
          }
        );
      }
    );