$(document).ready(function(){
  $('.search_dept').attr('disabled', 'true')
  $('.inia_projects').css('max-height',$(window).height()-185).css('overflow','scroll').css('overflow-x','hidden');
//  $('.tab-content').css('max-height',$(window).height()-255).css('overflow','scroll').css('overflow-x','hidden');
    $("#report_container").css('max-height',$(window).height()-255).css('overflow','scroll').css('overflow-x','hidden');
  $('#content').css('min-height', $(window).height()-185)
  $('.user_search,.dept_search,.project_users').css('width','200px');

  $('.dept_search').on("change", function(e) {
    if ($('.dept_search').select2('val') != '') {
      $('.search_dept').removeAttr('disabled')
    }else{$('.search_dept').attr('disabled', 'true')}
  });

  $('.user_search').select2({
    placeholder: "Select a user.",
    allowClear: true,
    ajax: {
      url: '/inia_members/group_users',
      dataType: 'json',
      type: "GET",
      quietMillis: 50,
      data: function (term) {
        return {
          term: term
        };
      },
      results: function (data) {
        var myResults = [];
        $.each(data.result, function (index, item) {
          myResults.push({
            'id': item.id,
            'text': item.text
          });
        });
        return {
          results: myResults
        };
      }
    },
    initSelection: function (item, callback) {
      var id = item.val();
      var text = item.data('option');
      var data = { id: id, text: text };
      callback(data);
    },
    formatSelection: function (item) { return (item.text); },
    escapeMarkup: function (m) { return m; }
  });

  var query_params = window.location.href.split('?');
  var project = query_params[0].split('/');
  project_id = project[project.length-1]



  $('.project_users').select2({
    placeholder: "Select a user.",
    allowClear: true,
    ajax: {
      url: '/inia_members/group_users',
      dataType: 'json',
      type: "GET",
      quietMillis: 50,
      data: function (term) {
        return {
          term: term,
          project_id: project_id,
          state: 'dept_user'
        };
      },
      results: function (data) {
        var myResults = [];
        $.each(data.result, function (index, item) {
          myResults.push({
            'id': item.id,
            'text': item.text
          });
        });
        return {
          results: myResults
        };
      }
    },
    initSelection: function (item, callback) {
      var id = item.val();
      var text = item.data('option');
      var data = { id: id, text: text };
      callback(data);
    },
    formatSelection: function (item) { return (item.text); },
    escapeMarkup: function (m) { return m; }
  });

  $('.dept_search').select2({
    placeholder: "Select a Dept.",
    allowClear: true,
    ajax: {
      url: '/inia_members/group_users',
      dataType: 'json',
      type: "GET",
      quietMillis: 50,
      data: function (term) {
        return {
          term: term,
          type: 'dept'
        };
      },
      results: function (data) {
        var myResults = [];
        $.each(data.result, function (index, item) {
          myResults.push({
            'id': item.id,
            'text': item.text
          });
        });
        return {
          results: myResults
        };
      }
    },
    initSelection: function (item, callback) {
      var id = item.val();
      var text = item.data('option');
      var data = { id: id, text: text };
      callback(data);
    },
    formatSelection: function (item) { return (item.text); },
    escapeMarkup: function (m) { return m; }
  });

  $('.repeat_a').click(function(){
    var nc = $(this).attr('class').split(' ')
    nc = nc[nc.length-1]
    console.log('--------')
    console.log(nc)
    var da = $(this).closest('tr').find('.'+nc).select2('data')
    var data = $(this).closest('tr').nextAll('')
    $.each( data, function( i, l ){
      $(this).find('.'+nc).select2('data',da)
      $(this).find('.config_save').removeAttr('disabled')
      $(this).find('form').append("<input type='hidden' name='a3' value="+ da['id'] +">")
    })
  });

//  $('.repeat_a4').click(function(){
//    var da1 = $(this).closest('tr').find('.name_search_a4').select2('data')
//    var data1 = $(this).closest('tr').nextAll('')
//    $.each( data1, function( i, l ){
//      $(this).find('.name_search_a4').select2('data',da1)
//
//      $(this).find('form').appendTo("<input type='hidden' name='a3' value="+ da1['id'] +">")
//    })
//  });

  $('.config_save').click(function(){
    var cur = $(this)
    var fd = $(this).closest('tr').find('form ').serialize();
    var users = $(this).closest('tr').find('.repeat_a').closest('td').find(".select2-container.user_search")
    var project = $(this).closest('tr').find('td').eq(0).text()
    var st = 1;
    console.log($(this).closest('tr').find('td'));
    $.each( users, function( ) {
      if ($(this).select2('val') == ''){
        st =0
        $('.notification-msg').show();
        $('.notification-msg').html("<li >Approval level was missing in '"+ project.toUpperCase() +"' project please add and continue.</li>")
        return false;
      }
    });
    if (st == 1) {
      $.ajax({
        url: '/inia_members',
        data: fd,
        type: 'POST',
        dataType: "json",
        success: function (data) {
          cur.attr('disabled', 'disabled')
          console.log(data);
        }
      });
    }
  });

  $('.select2-search-choice-close').filter(':visible').change(function(){

  });

  $('.save_all_approver').click(function(){
    var forms = $('.report_tble tr form')
    $.each(forms, function( ) {
      console.log($(this).serialize())
      array_form = $(this).serialize();
      var users = $(this).closest('tr').find('.repeat_a').closest('td').find(".select2-container.user_search")
      var project = $(this).closest('tr').find('td').eq(0).text()
      var st = 1;
      console.log($(this).closest('tr').find('td'));
      $.each( users, function( ) {
        if ($(this).select2('val') == ''){
          st =0
          $('.notification-msg').show();
          $('.notification-msg').html("<li >Approval level was missing in '"+ project.toUpperCase() +"' project please add and continue.</li>")
          return false;
        }
      });

      if (st == 1) {
        $.ajax({
          url: '/inia_members',
          data: array_form,
          type: 'POST',
          async: true,
          dataType: "json",
          success: function (data) {
            console.log(data);
          }
        });
      }else{ return false;}
    });

  });

  $('.user_search, .project_users').on("change", function(e) {
    $(this).closest('tr').find('.config_save').removeAttr('disabled')
    $('.save_all_approver').removeAttr('disabled')
  });
  if ($('.report_tble').is(":visible")){
    $('.save_all_approver').show()
  }
  $('.restricted').select2('disable');
  $('.project_users').click(function(){
    $('#errorExplanation').hide();
  });
  $('.restricted').click(function(){
    $('.flash').hide();
    $('#errorExplanation').show().html("<ul><li>This Role restricted by Nanba Admin</li></ul> ");
    return false;
  });

  $('input[type=button].save_all_approver').click(function(){
    var data = $('#member_role_form').serializeArray();
    $.post("/inia_members/0", data);
  });

});