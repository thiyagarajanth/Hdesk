
$(document).ready(function(){
  var query_params = window.location.href.split('?');
  var cur_project_id = query_params[0].split('/')[4];

  if ($("select#category_approval_configs_project_category_id").is(":visible")){
      $("select#category_approval_configs_project_category_id option").each(function( index ) {
          str = $(this).text()
          console.log([str,'-----'])
          $(this).text( allTitleCase(str) );
          function allTitleCase(inStr)
          {
              return inStr.replace(/\w\S*/g, function(tStr)
              {
                  return tStr.charAt(0).toUpperCase() + tStr.substr(1).toLowerCase();
              });
          }
      })
  }

  $(".approval_role").hide()
  $("#role_div").click(function(){
   $(".approval_role").show()
  })
  $("#hide_role_div").click(function(){
   $(".approval_role").hide()
  })
  if (window.location.href.indexOf("level") > -1) {
    $(".approval_role").show()  
  }


  $( ".list_tag" ).autocomplete({
    source: function( request, response ) {
      project = cur_project_id
      va = $( ".list_tag" ).val()
      cat_id = $("#category_approval_configs_project_category_id option:selected").val();
      $.ajax({
          
      url: '/projects/' + project + '/approval_definitions/get_tags?project_id='+project+'&&category_id='+cat_id+'&&position=1',
      dataType: 'json',
      type: "GET",
      data: {query: va},
      
      success: function (data) {
        response($.map(data, function(v,i){
            return v
        }));
      }
      });
    }
  });

  $( ".list_tag_2" ).autocomplete({
    source: function( request, response ) {
      project = cur_project_id;
      cat_id = $("#category_approval_configs_project_category_id option:selected").val();
      $.ajax({
        url: '/projects/' + project + '/approval_definitions/get_tags',
        dataType: 'json',
        type: "GET",
        data: {project_id: project, category_id: cat_id, position : 1 },
        
        success: function (data) {
          response($.map(data, function(v,i){
              return v
          }));
        }
      });
    }
  });

//  $("#issue_due_date").on('focusout', function (e) {
//    setValidityDate()
//  });

  if ($('#issue_due_date').val() == ''){

    $("#issue_description").on('focus', function (e) {
      console.log("---------- text -----")
      setValidityDate()
    })
  }

    // Ticketing Approval POP Up response ----------------> START <---------------
    $("#respond_group :button").click(function(){
        var due_days = $('.due-date:last').attr('data_vaidity');
        var clarification = false;
        var approve = false;
        var reject = false;
        var msg = ''
        if ($(this).attr('name')=='approve'){
            approve = true;
            clarification = false;
            reject = false;
            msg = 'Ticket approval confirmation !'
            showModal('ajax-modal', '300px');
        }else if ($(this).attr('name')=='clarification'){
            approve = false;
            clarification = true;
            reject = false;
            msg = 'Ticket information request confirmation !'
            showModal('ajax-modal', '320px');
        }else if ($(this).attr('name')=='reject'){
            approve = false;
            clarification = false;
            reject = true;
            msg = 'Ticket rejection confirmation !'
            showModal('ajax-modal', '300px');
        }
        $('#ajax-modal').html(" <div><div id='interruption_content'> </div>" +
            "<div class='confirm_validity_date'> <div id='append_validity'></div>" +
            "<br>" +
            "<div style='margin-left: 10px'><span id='tkt_cmt_error'>Comments if any.</span><textarea cols='25' id='tkt_comment' maxlength='300' name='comment' rows='3' data-clarification='false' data-approve='true' data-reject='false'></textarea>" +
            "<span class='due_validity '> <button type='button' data-approve="+approve+" data-reject="+reject+" data-clarification="+clarification+" value='Submit' class='save_new_dueDate'  >Save</button> <button type='reset' class='cancel_dueDate' value='Reset'>Cancel</button></span>" +
            "</div></div>");
        $('.ui-dialog-title').html("<span style='float:left'>"+msg+"</span>");
        if (due_days > 0){
            $('#ajax-modal #append_validity').html("<span class='due_validity'>Validity Till  <span class='required'>*</span>   <input id='confirm_validity' type='text' name='validity_till' readonly></span>")
            $(function() { $('#confirm_validity').datepicker(datepickerOptions); });
            $( "#confirm_validity" ).datepicker( "option", "minDate", 0 );
            var cur_date = $('.due-date:last').text();
            var NewDate = addDays(new Date(), due_days);
            var from = cur_date.split(" ");
            var set_cur_date = from[2]+"-"+((new Date(Date.parse(from[1] +' 1, 2012')).getMonth()+1) )+"-"+from[0];
            $("#confirm_validity").val(set_cur_date);
            $('#confirm_validity').datepicker("option", "maxDate", NewDate);
            $('#ajax-modal').parent('div').css({'top':'130px', 'left': '375px'});

        }
    });

  if ($( "#respond_msg p:visible" ).size() > 1){
      $('#tkt_get_respond').hide();
      $('#respond_msg').show();
  }
  else
  {
      $('#respond_msg').hide();
      $('#tkt_get_respond').show();

  }

    $("#ajax-modal").on("click", ".cancel_dueDate", function(e){
        hideModal();
        $('#save_tkt').attr('disabled', false);
    });

    $("#ajax-modal").on("click", ".save_new_dueDate", function(e){
        e.preventDefault();
        e.stopImmediatePropagation();
        var txt = $('#ajax-modal #tkt_comment').val();
        var approve = $(this).attr('data-approve');
        var reject = $(this).attr('data-reject');
        var clarification = $(this).attr('data-clarification');
        if ($( "#confirm_validity:visible" ).size() > 0){
            if ($('#confirm_validity').val() ==''){
              $('#confirm_validity').closest('span').css('color','red')
              return false;
            }
        }
        confirm_duedate(txt, approve, reject, clarification);


//        hideModal();
//        return false;
    });
    function confirm_duedate(txt, approve, reject, clarification){
        var comments = '';
        var status = approve;

            comments = txt.trim();

        var back_status = clarification ;//$('#tkt_comment').attr('data-clarification');
        var  role = $('#approve_btn_tkt').attr('data-role');
        var clari = $('.p_clarification_btn').length
        var condition = ($.trim(comments).length < 1) && (status == 'false' || back_status== 'true')
        if (clari > 0 && $.trim(comments).length < 1){
            $('#ajax-modal #tkt_cmt_error').css('color','red');
            return false;
        }
        if (condition ){
            $('#ajax-modal #tkt_cmt_error').css('color','red');
            return false;
        }
        hideModal();
        p_id = $('#response_btn').attr('data-project_id');
        var  author = $('#approve_btn_tkt').attr('data-author');
        $.ajax({
            url: "/projects/"+ $('#approve_btn_tkt').attr('data-project_id') +"/approval_definitions/respond_ticket",
            type: 'get',
            data: {project_id: p_id, issue_id: $('#approve_btn_tkt').attr('data-issue_id'), comment: comments, status: status, role: role, clarification: back_status, due_date: $('#confirm_validity').val(), ticket_author: author },
            success: function (data) {
                if (data.result){
                    $('#tkt_get_respond').hide();
                    var url = $('#tkt_get_respond').attr('url')
                    window.location.href = url //"/projects/"+ $('#approve_btn_tkt').attr('data-project_id') +"/issues";
                }else{

                    $('#tkt_cmt_error').show();
                    $('#tkt_cmt_error').html("<div 'style=width:100%'><span style='float:left' >Please enter comment.</span><span style='float:right;margin-right:5%;color:red' >Approval workflow is missing for next level. Please contact your project manager or IT Ops Team.</span></div>");
                    return false;
                }
            }
        });
    };


  $('#tkt_get_respond').on('focus keypress', '#tkt_comment', function (e) {
      $('.tkt_counter_msg').show();
      $('#save_tkt').attr('disabled', false)
      var $this = $(this);
      var msgSpan = $this.parents('#get_respond').find('.tkt_counter_msg');
      var ml = parseInt($this.attr('maxlength'), 10);
      var length = $.trim(this.value).length;
      var msg = ml - length + ' characters of ' + ml + ' characters left';
      msgSpan.html(msg);
  });

  // Ticketing Approval response ----------------> END <---------------
  $('#tkt_form_btn,#tkt_form_btn1').click(function(){
      if ($('.active4').length > 0){
          $('.active4').val('')
      }
    var e = document.getElementById("ticketing_project_id");
    var p_id = e.options[e.selectedIndex].value;
    var s = document.getElementById("cat_select");
    var f_id = s.options[s.selectedIndex].value;
    if (p_id == ''){
        $('#errorExplanation').show().html("<ul><li>Please select Project / Dept.</li></ul> ")
        return false;
    }
    if (f_id == ''){
        $('#errorExplanation').show().html("<ul><li>Please select Category .</li></ul> ")
        return false;
    }
    if (!$('#s2id_tkt_frm_sub').is(":hidden") && ($.trim($(".suggest_tkt a span").text())=='Select a ticket' || $.trim($(".suggest_tkt a span").text())==' ')){
        $('#errorExplanation').show().html("<ul><li>Please select Request for.</li></ul> ")
        return false;
    }
    if ($('#due_date_area label .required').length > 0 && $('#issue_due_date').val() == ''){
     $('#errorExplanation').show().html("<ul><li>Please select Access Required Till.</li></ul> ")
        return false;   
    }
    // if ($.trim($(".suggest_tkt a span").text())=='Select a ticket' || $.trim($(".suggest_tkt a span").text())==' '){
    //     $('#errorExplanation').show().html("<ul><li>Please enter Request for.</li></ul> ")
    //     return false;
    // }
      console.log('txt------1--');
      console.log($('#normal_flow label:eq(2)').text())
    if ($("label:contains('Description & Reason for request*')").text() == 'Description & Reason for request*'){
        console.log('txt-----2---');
      if ($.trim($('#issue_description').val()) == '') {
          console.log('txt----3----');
        $('#errorExplanation').show().html("<ul><li>Please enter Description & Reason for request.</li></ul> ")
        return false;
      }
       else{
        $('#errorExplanation').hide();
        var txt = $('.suggest_tkt a span').text();
          console.log(txt)
          console.log('txt-----4---');
         $('<input>').attr({ type: 'hidden', name: 'tickets[task_name]', value: txt  }).appendTo('#issue-form');
//        return true;
      }
    }
  });



  if ( $("#category_approval_configs_project_category_id").is(":visible") ) {
      s = document.getElementById("category_approval_configs_project_category_id");
      category = s.options[s.selectedIndex].text
      id = s.options[s.selectedIndex].value
      check_cat_value(id)
  };



  $('#add_values').click(function(){
      count = $(".tk_app_val input[type='text']").length +1
      name1 = 'category_approval_configs[values][]'
      $('.tk_app_val div').append( $( "<input name="+name1+" size='30' placeholder='Value"+count +"'  type='text' class='list_tag_"+count+"'>" ) );
      if (count == 5){
          $('#add_values').hide()
      }

  });

    // $('#add_level').click(function(){
    //     count = $(".tk_app_form_tbl input[type='checkbox']").length
    //     name1 = 'category_approval_configs[levels][]'
    //     $('.tk_app_form_tbl thead tr ').append( $( "<th>A"+ count +"</th>" ) );
    //     $('#last_level').before( $( "<td><input name="+ name1 +" type='checkbox' value='1'></td>" ) );
    //     if (count == 8){
    //         $('#add_level').hide()
    //     }
    // });


  $('#category_approval_configs_project_category_id').bind( "change load", function( event ) {
      console.log('asaS');
          e = document.getElementById("category_approval_configs_project_category_id");
      category = e.options[e.selectedIndex].text
      id = e.options[e.selectedIndex].value
      check_cat_value(id)
  });

  $("#category_approval_configs_project_category_id").change(function() {
      id = $('option:selected', this).val()
      setTicketingNonTicketing(id)
  });

  $('#cat_select').bind( "change load", function( event ) {
      id = $('option:selected', this).val()
      $.ajax({
          url: '/projects/'+ cur_project_id +'/ticketing_project_categories/' + id +'',
          type: 'get',
          success: function(result) {
              if (result.need_approval){
console.log('----- asd-')
                  $('#ticketing_flow #tkt_cat').show();
                  $('#request_for').show();
                  $('#issue_sub').hide();
                  $('#frm_sub').attr('name', '')
                  $(".new_issue input[value='Create']").attr('id','tkt_form_btn')
                  $("label:contains('Description')").text('Description & Reason for request').append("<span style='margin-left:5px;color:red'>*</span>")
              }else{

                console.log('----- max--- val-----')
                  $('#request_for').hide();
                  $('#issue_sub').show();
                  $('#frm_sub').attr('name', 'issue[subject]');
                  $('#s2id_tkt_frm_sub').hide()
                  $("label:contains('Description & Reason for request*')").text('Description & Reason for request')
              }
          }
      });
  });



  $('#delete_cat').click(function(){
      d = document.getElementById("category_approval_configs_project_category_id");
      category = d.options[d.selectedIndex].text
      id = d.options[d.selectedIndex].value
      if (confirm("Are you sure you want to delete the <b>"+ category +"</b> Category")) {
          $.ajax({
              url: '/projects/'+ cur_project_id +'/ticketing_project_categories/' + id +'',
              type: 'DELETE',
              success: function(result) {
                  console.log('-------------')
                  if (result.file_content=='fails'){
                      $('#flash_notice').hide()
                      $('#errorExplanation').show().html("<ul><li>Sorry!, <b>"+ category +"</b> Category was associate with some records.</li></ul> ")
                  }else if (result.file_content=='okay'){
                      $('#errorExplanation').hide()
                      $('#flash_notice').show().html("<ul><li> <b>"+ category +"</b> was successfully deleted.</li></ul> ")
                      d.options.remove(d.selectedIndex)
                  }
              }
          });
      }
  });

  $('#request_for #tkt_frm_sub').click(function(){
      if ($('#ticketing_project_id').val() == '' && $('#cat_select').val() == ''){
          $('.tkt_err').show()
          $('.tkt_err ul li').html('<li>Please Select Project and Category.</li>');
          return false;
      }else if ($('#ticketing_project_id').val() == ''){
          $('.tkt_err').show()
          $('.tkt_err ul li').html('<li>Please Select Project.</li>');
          return false
      }else if ($('#cat_select').val() == ''){
          $('.tkt_err').show()
          $('.tkt_err ul li').html('<li>Please Select Category.</li>');
          return false
      }
      else {
          $('.tkt_err').hide()

      }
  });

  $('#cat_select').change(function(){
    cat = document.getElementById("cat_select");
    id = cat.options[cat.selectedIndex].value;
    if ($('#ticketing_project_id').val() == ''){
      $('.tkt_err').show()
      $('.tkt_err ul li').html('<li>Please Select Project.</li>');
      $("#cat_select option:selected").attr("selected", false);
    }else{
      $('.tkt_err').hide()
      $(".suggest_tkt").select2({
        placeholder: "Select a ticket",
        allowClear: true,
        ajax: {
          url: '/projects/' + cur_project_id + '/approval_definitions/associate_tickets?category_id=' + id,
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
        }
      });
    }
  });

  // onload trigger ticketing option
  if ($('.new_issue #issue_tracker_id').is(":visible")){
      updatetrackerFrom("/projects/"+ cur_project_id +"/approval_definitions/set_tracker.js ")
  }
 // multiple interruption

  $(document).on('click', ".interrupt_ico", function() {

      console.log($(this).attr('data_interrupt'));
    approval = $(this).attr('data_interrupt');
    role_id = $(this).attr('data_interrupt_role_id');
    $('#category_approval_configs_'+approval)

    if ($('#category_approval_configs_'+approval).prop('checked')==true) {

      $('#ajax-modal').html(" <div class='box '><div id='interruption_content'> </div>" +
        " <table><tr id='interruption_type'><th >Type of Interruption <span class='required'>*</span> </th><td> <input type='radio' name='type' value='override'><label for='override'>Override</label><input type='radio' name='type' value='intermediate'><label for='override'>Intermediate</label></td></tr>" +
        "<tr><th> </th><td><input type='hidden' id='inter_level' value=" + approval + "> </td></tr>   " + "<tr><th> </th><td><input type='hidden' id='inter_level_role' value=" + role_id + "> </td></tr>   " +
        "<tr><th>User To Approve  <span class='required'>*</span></th><td>   <select id='user_select'>" +
        "<option value=''>--- Select User ---</option></select></td></tr>" +
        "<tr><th></th><td> <button type='button' value='Submit' class='save_interrupt'>Save</button> <button type='reset' class='cancel_interrupt' value='Reset'>Cancel</button></td></tr></table>" +
        "</div>");

      $.ajax({url: " /approval_definitions/group_users", success: function (result) {
//        $("<option></option>").text('--- Please select ---').val(0);
        $.each(result.users, function (index, item) { // Iterates through a collection
          $("#user_select").append( // Append an object to the inside of the select box
            $("<option></option>").text(item[1]).val(item[0]));
        });
      }});


      showModal('ajax-modal', '500px');
      setTimeout(function () {
        if ($('.' + approval).length != 0) {
          $('#ajax-modal').append("<button type='button' value='Submit' id='remove_interrupt'>Remove</button>")
          checked = $("input[name='interruption[type][]'][class=" + approval + "]").val()
          select_value = $("input[name='interruption[user][]'][class=" + approval + "]").val()
          $(":radio[value=" + checked + "]").attr('checked', true);
          console.log(checked, approval, select_value)
          $("#user_select option[value=" + select_value + "]").attr("selected", "selected");
        }
      }, 500);
    }else{
      alert('please select the '+ approval)
    }
  });

  $(document).on('click', "#interruption_type", function() {
    approval = $('#inter_level').val()
    if ($("input:radio[name='type']:checked").val() == 'override'){
      $('#interruption_content').html("<b>Your going to Override "+ approval +"</b>")
    }else if ($("input:radio[name='type']:checked").val() == 'intermediate'){
      $('#interruption_content').html("<b>Your going to add Intermediate approval before "+ approval +"</b>")
    }
    $('#interruption_content').html()
  });

  $(document).on('click', ".cancel_interrupt", function() {
    hideModal();
  });

  $(document).on('click', "#remove_interrupt", function() {
    approval = $('#inter_level').val()
    role_id = $('#inter_level_role').val()
    id = $("#user_select option:selected").val()
    params =[ approval, id,role_id ]
    $('.'+approval).remove()
    $('<input>').attr({ type: 'hidden', class: approval, name: 'interruption[delete][position][]', value: approval  }).appendTo('.tk_ap_form form');
    $('<input>').attr({ type: 'hidden', class: approval, name: 'interruption[delete][user][]', value: id  }).appendTo('.tk_ap_form form');
    $('<input>').attr({ type: 'hidden', class: approval, name: 'interruption[delete][role][]', value: role_id  }).appendTo('.tk_ap_form form');
    hideModal();
    $("*[data_interrupt="+ approval +"]").removeClass('interrupt_grid');
  });


  $(document).on('click', ".save_interrupt", function() {
    override = $("input:radio[name='type']:checked").val();
    approval = $('#inter_level').val()
    id = $("#user_select option:selected").val();
    role_id = $('#inter_level_role').val();
    params =[ approval, override, id ];
    $('.'+approval).remove()
    $('<input>').attr({ type: 'hidden', class: approval, name: 'interruption[type][]', value: override  }).appendTo('.tk_ap_form form');
    $('<input>').attr({ type: 'hidden', class: approval, name: 'interruption[position][]', value: approval  }).appendTo('.tk_ap_form form');
    $('<input>').attr({ type: 'hidden', class: approval, name: 'interruption[user][]', value: id  }).appendTo('.tk_ap_form form');
    $('<input>').attr({ type: 'hidden', class: approval, name: 'interruption[role][]', value: role_id  }).appendTo('.tk_ap_form form');
    hideModal();
    console.log('---- rews--------');

    console.log($("*[data_interrupt="+ approval +"]"))
    $("*[data_interrupt="+ approval +"]").addClass('interrupt_grid');
  });
  console.log('=============loaded =====')
  if ($("td.tk_app_val").is(":visible")) {
    var data_ticket = $('td.tk_app_val').attr('data_ticket');
    if (data_ticket != '') {
      $.ajax({url: " /approval_definitions/update_interruption?tickets=" + data_ticket, success: function (result) {
        console.log('=============1=====')
        console.log(result.data)
        $.each(result.data, function (index, item) {
          add_level = item[0].replace(/ /g,"_")
          $("*[data_interrupt=" + add_level + "]").addClass('interrupt_grid');
          console.log(item[0])
          $('<input>').attr({ type: 'hidden', class: add_level, name: 'interruption[type][]', value: item[1]  }).appendTo('.tk_ap_form form');
          $('<input>').attr({ type: 'hidden', class: add_level, name: 'interruption[position][]', value: item[0]  }).appendTo('.tk_ap_form form');
          $('<input>').attr({ type: 'hidden', class: add_level, name: 'interruption[user][]', value: item[2] }).appendTo('.tk_ap_form form');
          $('<input>').attr({ type: 'hidden', class: add_level, name: 'interruption[role][]', value: item[3]  }).appendTo('.tk_ap_form form');
        });
      }});
    }
  }



  // ---------------------------- Star rating to Resolved tickets ----------------------------------
//  var state = 0;
  $('form.edit_issue').on('submit',function(e){
    if ($("#issue_status_id option:selected").text() == 'Closed'){
      var rating = $('.edit_issue input[name=rating]:first').val()
      console.log('----------rating')
      console.log(rating)
      if (rating > 0){
        return true;
      }else{
        ratingModel();
        e.preventDefault;
        return false;
      }
    };
  });

  $("#issue_status_id").on('change', function () {
    if ($('option:selected', this).text() == 'Closed') {
      ratingModel();
    }
  });

  $('.controller-issues .ui-dialog-titlebar-close').click(function(){
    $("#issue_status_id").val($("#issue_status_id").attr('data_status_id'));
  });

  $(document).on('click', "#rate_submit", function() {
    console.log('===============clicked===============')
    rate = parseInt($('#star_rate').find('span').attr('userRate'));
    rate.isNaN
    if (isNaN(rate)){
      $('#star_rate').html("<span style='color:red';>Please rate it.</span>")
      return false;
    }
    else if (rate > 0){
      hideModal();
      issue_id = cur_project_id;
      rating = $('#star_rate').find('span').attr('userRate');
      $('<input>').attr({ type: 'hidden', name: 'rating', value: rating  }).appendTo('form.edit_issue');
    }else{
      $("#issue_status_id").val($("#issue_status_id").attr('data_status_id'));
      hideModal();
    }
  });

   if ($("#issue_status_id").is(":visible")==true){
     $(document).keyup(function(e) {
       if (e.keyCode == 27) { // escape key maps to keycode `27`
         $("#issue_status_id").val($("#issue_status_id").attr('data_status_id'));
         hideModal();
       }
     });
   }

  if ($("#my_account_form input[type='submit']").is(":visible")==true) {
    console.log('------------ 123 -------------------')
    var id = $("#my_account_form input[type='submit']").attr('data_user_id')
    setRating(id, $('#user_avg_rating'), 'lopk')
  }

  $('.manager_view_rating').each(function() {
    var rate = $(this).attr('data-rating');
    var id = $(this).attr('data-user_id')
    var att_id = $(this).attr('id');
      var query_params = window.location.href.split('?')
      var project_id = query_params[0].split('/')[4]
    setRating(id, $('#'+att_id), project_id)
  });

  // ---------------------------- Star rating to Resolved tickets ----------------------------------


  if ($('#issue_status_id').attr('data_is_author')=='false') {
    $('#issue_status_id option').each(function () {
      if ($(this).text() == 'Closed') {
        $(this).prop('disabled', true);
      }
    });
  }


  $("#search_category").select2({
//    placeholder: "Select a Category",
    allowClear: true,
    ajax: {
      url: '/projects/' + cur_project_id + '/ticketing_project_categories/',
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
        console.log('======log===');
        console.log(data);
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

    }
  });

//  $("#search_tag").hide();

  $(document.body).on("change ","#search_category",function(){
    var ids = $('#search_tag').val();
    callTagFilter([ids])
  });

  $("input[type=submit].find_tag").click(function(e){
    if ($('#search_category').val() ==''){
      $('#s2id_search_category').css('border', '1px solid red')
      if ($('#search_alert').is(":visible") == false) {
        $('.list_container form').append("<span style='color:red;margin-left:10px' id='search_alert'> Please select a Category</span>")}
      e.preventDefault();
    }
  });

});


setTimeout(function() {
  var rec = $('#search_tag').attr('data-ids');
  var ids = [];
    if (rec != null){
      ids = rec.split(' ');
    }
  callTagFilter(ids);
}, 2000);

function callTagFilter(ids){
  cat_id = $("#search_category").val();
  var query_params = window.location.href.split('?')
  var cur_project_id = query_params[0].split('/')[4]
  project = cur_project_id;
  $("#search_tag").select2({
    placeholder: "Select a ticket",
    allowClear: true,
    quietMillis: 1000,
    multiple: true,
    ajax: {
      url: '/projects/' + project + '/approval_definitions/associate_tickets?category_id=' + cat_id,
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
    initSelection : function (element, callback) {
      console.log('------ji--');
      var id = $(element).val();
      console.log(ids);
      console.log('------ji--');
      if(id !== "") {
        $.ajax('/projects/' + project + '/approval_definitions/filterTag', {
          data: {ids: ids},
          dataType: "json"
        }).done(function(data) {
          console.log(data.data);
          callback(data.data);
        });
      }
    }
  }).select2('val', ids);
}

function ratingModel(){
  $('#ajax-modal').html(" <div class='box box1'><div id='jRate'></div></div><div class='rate_master'><span id='star_rate'></span><button type='submit' id='rate_submit'>Continue</button></div>");
  showModal('ajax-modal', '300px');
  $('.ui-dialog-title').html("<span style='float:left'>Feedback with your Rating.</span>")
  $("#jRate").jRate({
    width: 40,
    height: 40,
    backgroundColor: 'black',
    startColor: '#f58220',
    endColor: '#f58220',
    onSet: function (rating) {
//      $('#star_rate').text("Selected Rating: " + rating).attr('data_userRate',rating);
    },
    onChange: function(rating) {
        switch (rating) {
            case 0:
                day = "None";
                break;
            case 1:
                day = "Unhappy";
                break;
            case 2:
                day = "Okay";
                break;
            case 3:
                day = "Happy";
                break;
            case 4:
                day = "Very Happy";
                break;
            case 5:
                day = "Amazing";
                break;
        }
        if (rating > 0) {
            $('#star_rate').html("Your Rating: <span style='color:#f58220;font-weight: bold' userRate="+rating+">" + day + "</span>");
        }else{
            $('#star_rate').html("")
        }
    }
  });
}


(function($) {
  $.fn.ibox = function() {

    // set zoom ratio //
    resize = 100;
    ////////////////////
    var img = this;
    img.parent().append('<div id="ibox" />');
    var ibox = $('#ibox');
    var elX = 0;
    var elY = 0;

    img.each(function() {
      var el = $(this);

      el.mouseenter(function() {
        ibox.html('');
        var elH = el.height();
        elX = el.position().left - 6; // 6 = CSS#ibox padding+border
        elY = el.position().top - 6;
        var h = el.height();
        var w = el.width();
        var wh;
        checkwh = (h < w) ? (wh = (w / h * resize) / 2) : (wh = (w * resize / h) / 2);

        $(this).clone().prependTo(ibox);
        ibox.css({
          top: elY + 'px',
          left: elX + 'px'
        });
        console.log(wh)

        ibox.stop().fadeTo(200, 1, function() {
          $(this).animate({top: '-='+(resize/2), left:'-='+wh-30},400).children('img').animate({height:'+='+resize,width:'+='+resize},400);
        });
      });

      ibox.mouseleave(function() {
        ibox.html('').hide();
      });
    });
  };
})(jQuery);

$(document).ready(function() {
  $('img.gravatar').ibox();
});




function setRating(id,selector, project_id){
  $.ajax({
    url: '/projects/'+project_id+'/issues/avg_rating',
    type: "GET",
    data: {user_id: id},
    success: function (data) {
      var rate =  data.result.avg
      var count =  data.result.count
      console.log('---------------')
      console.log([data.result.avg, id])
//      selector.attr('title',rate+' Rating')
        console.log([$('#userRating_user').data('user_id'), parseInt(id)])
        if ($('#userRating_user').data('user_id')==parseInt(id)){
            $('#userRating_user').text(rate)
            $('#userRating_resolved').text(count)

        }
      selector.attr('title',rate +' Rating / out of '+ count +' tickets')
      console.log(selector)
      selector.jRate({
        readOnly: true,
        precision: 0.2,
        rating: rate,
        width: 15,
        height: 15,
        backgroundColor: 'black',
        startColor: '#f58220',
        endColor: '#f58220'
      });
//        <span class='star medium' style='margin: 5px auto;float: left'><a>"+data.result.avg+"</a></span>
      $('#user_avg_rating').css('float','left').after("<span style='float:right'><span>Based on " + data.result.count+" ratings.</span></span>")

    }
  })
}

function addDays(theDate, days) {
  return new Date(theDate.getTime() + days*24*60*60*1000);
}

function setValidityDate(){

  var d3 = $("#issue_due_date").val()
  console.log(d3)
  var d2 = new Date(d3)
  tag = $(".suggest_tkt").select2('val');
  var query_params = window.location.href.split('?')
  var cur_project_id = query_params[0].split('/')[4]
  url = query_params[0].split('/')
  if (url.length < 6){
    tag = $("#frm_sub").attr('data-tag')
  }
  if (tag !='null') {
    $.ajax({
      url: '/projects/' + cur_project_id + '/approval_definitions/tag_duedate?tag=' + tag,
      dataType: 'json',
      type: "GET",
      success: function (result) {
        if (result.data) {
          var newDate = addDays(new Date(), result.data);
          var d1 = newDate
          if ((d1 > d2) == false) {
            // $("#issue_due_date").datepicker('setDate', newDate);
            $( "#issue_due_date" ).datepicker( "option", "minDate", 0 );
            $('#issue_due_date').datepicker("option", "maxDate", newDate);
          }
          var wrapped = $('#due_date_area label');
          wrapped.find('span').remove();
          wrapped.append("<span class='required'> *</span>")
        } else {
          $("#issue_due_date").val('')
          var wrapped = $('#due_date_area label');
          wrapped.find('span').remove();
          return wrapped.html();
        }

      }
    })
  }
}

function setTicketingNonTicketing(id){
  var query_params = window.location.href.split('?');
  var cur_project_id = query_params[0].split('/')[4];
    $.ajax({
        url: '/projects/'+ cur_project_id +'/ticketing_project_categories/' + id +'',
        type: 'get',
        success: function(result) {
            if (result.need_approval){
                $('.approval').show();
            }else{
                $('.approval').hide();
            }
        }
    });

}

function updatetrackerFrom(url) {
    $('#all_attributes input, #all_attributes textarea, #all_attributes select').each(function(){
        $(this).data('valuebeforeupdate', $(this).val());
    });
    $.ajax({
        url: url,
        type: 'post',
        data: $('#issue-form').serialize(),
        success: function(result) {
                if (result.project == true){
                    $('#ticketing_flow p:first').show()
                }else{
                    $('#ticketing_flow p:first').hide()
                }
                if (result.approval == true){
                  $('#ticketing_flow #tkt_cat').show();
                  if (result.cat_approval == true){
                    $('#request_for').show();
                    var e = document.getElementById("cat_select");
                    var id = e.options[e.selectedIndex].value;
                    if (id != ''){get_select2_values();
                    s = $('#frm_sub').val()
                    d = $('#tkt_frm_sub').attr('data-tag')
                    $(".suggest_tkt").select2('data',{id: d, text:s});
                    $('#issue_sub').hide();
                    $('#frm_sub').attr('name', '')
                    $(".new_issue input[value='Create']").attr('id','tkt_form_btn')
                    $("label:contains('Description')").text('Description & Reason for request').append("<span style='margin-left:5px;color:red'>*</span>")
                 }
                }

            }else{
                $('#request_for').hide();
                $('#issue_sub').show();
              $('#frm_sub').attr('name', 'issue[subject]');
                $('#ticketing_flow #tkt_cat, #s2id_tkt_frm_sub').hide()
                    $("label:contains('Description & Reason for request*')").text().text('Description & Reason for request')
            }
        }
    });
}


function check_cat_value(id){
    if (id > 0) {
        $('.app_cat_action').show()
    } else {
        $('.app_cat_action').hide()
    }
}

function get_select2_values(){
  cat = document.getElementById("cat_select");
  id = cat.options[cat.selectedIndex].value;
  var query_params = window.location.href.split('?');
  var cur_project_id = query_params[0].split('/')[4];
  if ($('#ticketing_project_id').val() == ''){
    $('.tkt_err').show()
    $('.tkt_err ul li').html('<li>Please Select Project.</li>');
    $("#cat_select option:selected").attr("selected", false);
  }else{
    $('.tkt_err').hide()
    $(".suggest_tkt").select2({
      placeholder: "Select a ticket",
      allowClear: true,
      ajax: {
        url: '/projects/' + cur_project_id + '/approval_definitions/associate_tickets?category_id=' + id,
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
      }
    });
  }
}

document.querySelector('form').onkeypress = checkEnter;
function checkEnter(e){
 e = e || event;
 var txtArea = /textarea/i.test((e.target || e.srcElement).tagName);
 return txtArea || (e.keyCode || e.which || e.charCode || 0) !== 13;
}

// Placeholder multi line issue ( Firefox ) fixed using the below script

$(function() {
    var isOpera = !!window.opera || navigator.userAgent.indexOf(' OPR/') >= 0;
// Disable for chrome which already supports multiline
    if (! (!!window.chrome && !isOpera)) {
        var style = $('<style>textarea[data-placeholder].active4 { color: #bdb9b9; }</style>')
        $('html > head').append(style);
        $('textarea[placeholder]').each(function(index) {
            var text = $(this).attr('placeholder');
            var match = /\r|\n/.exec(text);
            if (! match)
                return;
            $(this).attr('placeholder', '');
            $(this).attr('data-placeholder', text);
            $(this).addClass('active4');
            $(this).val(text);
        });
        $('textarea[data-placeholder]').on('focus', function() {
            if ($(this).attr('data-placeholder') === $(this).val()) {
                $(this).attr('data-placeholder', $(this).val());
                $(this).val('');
                $(this).removeClass('active4');
            }
        });
        $('textarea[data-placeholder]').on('blur', function() {
            if ($(this).val() === '') {
                var text = $(this).attr('data-placeholder');
                $(this).val(text);
                $(this).addClass('active4');
            }
        });
    }
});