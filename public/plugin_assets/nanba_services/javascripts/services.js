$(document).ready(function(){
  $('.sync_ids').css('display','none');

  $('#sync_type_specific_user').on('click',function(){
    $('#flash_notice,.syn_err').hide();
    $("#from,#emp_ids").val('');
    $('.sync_ids label').css('color','rgb(92, 88, 88)');
    $('#emp_ids').css('border','1px solid rgb(179, 173, 173)');
    $('.sync_ids').show();
  });
  $('#sync_type_full_sync').click(function(){
    $('#flash_notice,.syn_err,.sync_ids').hide();
    $("#from,#emp_ids").val('');
    $('.sync_ids label').css('color','rgb(92, 88, 88)');
    $('#emp_ids').css('border','1px solid rgb(179, 173, 173)');
    $('#emp_ids').val('')
  });

  $('.sync_type').click(function(){
    name = $(this).attr('data-name')
    $('.sync_sevice h3 span').html(name.toUpperCase())
    $('#from').datepicker("option", "maxDate", 0);
    $('<input>').attr({ type: 'hidden',  name: 'sync_from', value: name  }).appendTo('.sync_sevice');
  });
  $('#cancel_sync').click(function(){
    $("#from,#emp_ids").val('');
    $('.sync_ids label').css('color','rgb(92, 88, 88)');
    $('#emp_ids').css('border','1px solid rgb(179, 173, 173)');
    $('.sync_sevice').hide()
  });
  $('.sync_type').click(function(){
    $('#flash_notice,.syn_err').hide();
    $("#from,#emp_ids").val('');
    $('.sync_ids label').css('color','rgb(92, 88, 88)');
    $('#emp_ids').css('border','1px solid rgb(179, 173, 173)');
    $('.sync_sevice').show();
  });

  $('#emp_ids').keypress(function(e) {

    if (e.which != 44 && e.which != 8 && e.which != 0 && (e.which < 48 || e.which > 57   )) {

      return false;
    }
  });
  $('#update_sync').click(function(){
    url = $(this).attr('data-url')
    data1 = $(".sync_sevice :input").serialize()
//    console.log(url)
//    url: 'http://'+ url+'/service/nanba_pull',
    if ($('#sync_type_specific_user').is(":checked") && $('#emp_ids').val() == ''){
      $('.sync_ids label').css('color','red');
      $('#emp_ids').css('border','1px solid red');
      return false;
    }
    $('#flash_notice').show();
    $('#flash_notice').html("<li >Synchronization is Processing...</li>")
    setTimeout(function () {
      $.ajax({
        url: 'manul_sync',
        async: false,
        data: data1  ,
        type: 'get',
        success: function (result) {
          console.log(result)
        }
      }).done(function() {
        $('#flash_notice,.syn_err').hide();
        $('#flash_notice').show();
        $('#flash_notice').html("<li >Synchronization was done.</li>")
      })
        .fail(function() {
          $('#flash_notice,.syn_err').hide();
          $('.notification-msg').show();
          $('.notification-msg').html("<li >Error occured while Synchronization.</li>")
        })
    }, 500);
    $("#from,#emp_ids").val('');
    $('.sync_sevice').hide()
  });
});