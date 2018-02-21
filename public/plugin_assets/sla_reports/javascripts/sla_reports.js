$(document).ready(function(){
  if ($(".selected").is(":visible") == true){
    $('.reports').addClass('selected')
  }

  $('select option')
    .filter(function() {
      return $.trim(this.text).length == 0;
    })
    .remove();

  $('.popupWind a').click(function(event) {
    event.preventDefault();
    window.open($(this).attr("href"), "_blank", "width=1100,height=750,scrollbars=yes");
  });


  id = $("#sla_filter #page_type").val()
  if ($('#sla_filter').is(':visible')){
    check_params(id)
    $('#sla_report_tbl').show()
  };
      $("#sla_filter #page_type").on( "load change", function( event )  {
        id = $('option:selected', this).val()
        $('#sla_report_tbl').hide()
        $('#user_id').val(' ')
        check_params(id)
      });



  // this is for sla not met error
  $("#wktime_save").click(function (e) {


    status = 0
    $(".not_met_reason.add_sla_color").each(function() {
      if ($.trim($(this).val()) == ''){
        status = 1
      }else{
        issue_id = $(this).closest('tr').children('td:nth-child(2)').find('#time_entry__issue_id').val();
        reason = $(this).closest('tr').find('.add_sla_color').val();
        $('<input>').attr({ type: 'hidden',  name: 'not_met_issue_ids[]', value: issue_id  }).appendTo('#wktime_edit');
        $('<input>').attr({ type: 'hidden',  name: 'sla_reasons[]', value: reason  }).appendTo('#wktime_edit');
      }
    });
    if (status==1) {
      $('#wktime_save').prop('disabled', true);
      $('.not_met_header').show();
      return false;
      e.preventDefault();

    }

  });
  $('.time-entry  #time_entry__issue_id').each(function(i, obj) {
    var $cur_obj = $(this);
    var issue_id = $(this).val()
    $.ajax({
      url: '/projects/10/sla_reports/get_not_met_sla_tickets_on_load',
      data: { issue_id: issue_id, hours: 0 },
      type: 'get',
      success: function(result) {
console.log(result.status[0][0])
console.log(result)
        if (result.status[0][0]==false){
          $cur_obj.closest('tr').find('input[type=text]').removeClass('not_met_sla')
          if ($cur_obj.closest('tr').find('input[type=text]').hasClass('not_met_sla') == false ){
            $('#slaerrorExplanation').hide();
            $('#wktime_save').prop('disabled', false);
            $cur_obj.closest('tr').find('.not_met_reason').removeClass('add_sla_color')
            $cur_obj.closest('tr').find('.not_met_reason').hide()
          }
        }else if (result.status[0][0] == true ){
          if ($cur_obj.closest('tr').hasClass('not_met_sla') == false ){
            $cur_obj.closest('tr').find('.not_met_reason').show();
            $cur_obj.closest('tr').find('.not_met_reason').attr('value',result.status[0][1])
            $('.not_met_header').show()
          }
        }
      }
    });

  });

  $('.user_rating').each(function(){
    var rating = $(this).attr('data-rating')
    $(this).attr('title',rating +' Rating ')
    $(this).jRate({
      readOnly: true,
      precision: 0.2,
      rating: rating,
      width: 15,
      height: 15,
      backgroundColor: 'black',
      startColor: '#f58220',
      endColor: '#f58220'
    });
  });

//  var options = $('#rate_user_id option');
//  var arr = options.map(function(_, o) { return { t: $(o).text(), v: o.value }; }).get();
//  arr.sort(function(o1, o2) { return o1.t > o2.t ? 1 : o1.t < o2.t ? -1 : 0; });
//  options.each(function(i, o) {
//    o.value = arr[i].v;
//    $(o).text(arr[i].t);
//  });

 });

function check_params(id){
  $('#sla_report_tbl').hide();
  $('#user_id').val($('#user_list_sla').attr('data-user-id'));
  if ($('#to').val() != ''){
    $('#to').prop('disabled', false);
    $('#from').prop('disabled', false);
  }
  if (id == 1){
    $('#user_list_sla').hide()
    $('.sla_query').show()
//    $('#sla_report_tbl').show()

  }else if (id > 1){
    $('#user_list_sla').show()
    $('.sla_query').show()
//    $('#sla_report_tbl').show()
  }
  else{
    $('#user_list_sla').hide()
    $('.sla_query').hide()
    $('#sla_report_tbl').hide()
  }

}


$(document.body).on('keyup',".add_sla_color",function(){
  if ($.trim($(this).val()) != ''){
    $('#wktime_save').prop('disabled', false);
  }else{$('#wktime_save').prop('disabled', true);}
});



// this is for sla not met error
$(document.body).on('keyup',".hours input[type=text]",function(){
  $('.flash').hide();
  sum = 0;
  $.each($(this).closest('tr').find('.hours input[type=text]'), function( ) {
    sum += Number($(this).val());
  });

  $cur_obj = $(this);
  issue_id = $(this).closest('tr').children('td:nth-child(2)').find('#time_entry__issue_id').val()
  $.ajax({
    url: '/projects/10/sla_reports/get_not_met_sla_tickets',
    data: { issue_id: issue_id, hours: sum },
    type: 'get',
    success: function(result) {
console.log(result.status[0][0])
console.log(result)
      if (result.status[0][0]==true){
        console.log('===== 1 ======')
        $cur_obj.closest('tr').find('input[type=text]').removeClass('not_met_sla')
        if ($('.time-entries tr td input[type=text]').hasClass("not_met_reason") == false){
          $('.not_met_header').hide()
        }
        if ($('.time-entries tr td input[type=text]').hasClass("add_sla_color") == false){
          console.log('=== came ====')
          $('#slaerrorExplanation').hide();
          $('#wktime_save').prop('disabled', false);
        }
        if ($cur_obj.closest('tr').find('input[type=text]').hasClass('not_met_sla') == false ){
          $cur_obj.closest('tr').find('.not_met_reason').removeClass('add_sla_color')
          $cur_obj.closest('tr').find('.not_met_reason').hide()
        }
      }else if (result.status[0][0]==false ){
        console.log('===== 2 ======')
        if ($('.time-entries tr td input[type=text]').hasClass("not_met_reason") == false){
          $('.not_met_header').hide()
        };
        $('#slaerrorExplanation').show().html(" <div class='flash error' id='flash_error'>Could not save Time: You have exceeded the SLA time for resolving the issue. Please provide the Justification. </div>");
        if (Number($cur_obj.val() ) != 0 && $cur_obj.closest('tr').hasClass('not_met_sla') == false ){
          $cur_obj.addClass('not_met_sla');
          $cur_obj.closest('tr').find('.not_met_reason').show().addClass('add_sla_color');
          $cur_obj.closest('tr').find('.not_met_reason').attr('value',result.status[0][1])
          $('.not_met_header').show()
        }else{
          if ($('.time-entries tr td input[type=text]').hasClass("add_sla_color") == false){
            $('#slaerrorExplanation').hide();
          }
        }
      }
    }
  });
  if ($.find(".add_sla_color").length == 0 ) {
//    $('.not_met_header').hide()
  }

});

$(document.body).on('change',"#time_entry__issue_id",function(){
  $('.flash').hide();
  sum = 0;
  $.each($(this).closest('tr').find('.hours input[type=text]'), function( ) {
    sum += Number($(this).val());
  });

  $cur_obj = $(this);
  issue_id = $(this).closest('tr').children('td:nth-child(2)').find('#time_entry__issue_id').val()
  $.ajax({
    url: '/projects/10/sla_reports/get_not_met_sla_tickets',
    data: { issue_id: issue_id, hours: sum },
    type: 'get',
    success: function(result) {
console.log(result.status[0][0])
console.log(result)
console.log('-----------')

      if (result.status[0][0]==true){
//        $cur_obj.closest('tr').find('input[type=text]').removeClass('not_met_sla')
        if ($('.time-entries tr td input[type=text]').hasClass("add_sla_color") == false){
          $('#slaerrorExplanation').hide();
          $('#wktime_save').prop('disabled', false);
        }
        if ($cur_obj.closest('tr').find('input[type=text]').hasClass('not_met_sla') == false ){
          $cur_obj.closest('tr').find('.not_met_reason').removeClass('add_sla_color')
          $cur_obj.closest('tr').find('.not_met_reason').hide()
        }
      }else if (result.status[0][0]==false ){
        $('#slaerrorExplanation').show().html(" <div class='flash error' id='flash_error'>Could not save Time: You have exceeded the SLA time for resolving the issue. Please provide the Justification.</div>");
        if (Number($cur_obj.val() ) != 0 && $cur_obj.closest('tr').hasClass('not_met_sla') == false ){
          $cur_obj.closest('tr').find('.not_met_reason').show().addClass('add_sla_color');
          $cur_obj.closest('tr').find('.not_met_reason').attr('value',result.status[0][1])
          $('.not_met_header').show()
        }else{
          if ($('.time-entries tr td input[type=text]').hasClass("add_sla_color") == false){
            $('#slaerrorExplanation').hide();
          }
        }
      }
    }
  });
  if ($.find(".add_sla_color").length == 0 ) {
//    $('.not_met_header').hide()
  }

});
