$(document).ready(function() {
    $('#response_btn').click(function () {
        $('#response_area').show();
    })
    $('#cancel_response').click(function(){
        $('#cmt_error').css('color','black')
        $('#response_area, .counter_msg').hide();
        $('#comment').val('');
    });


    if ($( "#respond_msg p:visible" ).size() > 1){
       $('#get_respond').hide();
        $('#respond_msg').show();
    }
     else
    {
        $('#respond_msg').hide();
        $('#get_respond').show();

    }
    $("#save_response").unbind().click(function() {

        if ($.trim($('#comment').val()).length < 1){
            $('#cmt_error').css('color','red');
            return false;
        }
        p_id = $('#response_btn').attr('data-project_id')
        $.ajax({
            url: "/issue_slas/add_response_sla",
            type: 'get',
            data: {project_id: p_id, issue_id: $('#response_btn').attr('data-issue_id'), comment: $('#comment').val()},
            success: function (data) {
                console.log(data)
                $('#respond_msg').show();
                $('#get_respond').hide(); $('#respond_msg p').replaceWith("<p>Responded by " + data[1] + ", Responded about less than a minute ago  </p><li><ol>"+ data[2]+ "</ol></li><hr    ><br>")
            }
        });

    });


    $('#get_respond').on('focus keypress', '#comment', function (e) {
        $('.counter_msg').show();
        var $this = $(this);
        var msgSpan = $this.parents('#get_respond').find('.counter_msg');
        var ml = parseInt($this.attr('maxlength'), 10);
        var length = $.trim(this.value).length;
        var msg = 'Left : ' + (ml - length) ;
        msgSpan.html(msg);
    });


    $(".priority_list tbody tr input[type='text']").keydown(function (e) {
        // Allow: backspace, delete, tab, escape, enter and .
        if ($.inArray(e.keyCode, [46, 8, 9, 27, 13, 110, 190]) !== -1 ||
            // Allow: Ctrl+A
            (e.keyCode == 65 && e.ctrlKey === true) ||
            // Allow: home, end, left, right
            (e.keyCode >= 35 && e.keyCode <= 39)) {
            // let it happen, don't do anything
            return;
        }
        // Ensure that it is a number and stop the keypress
        if ((e.shiftKey || (e.keyCode < 48 || e.keyCode > 57)) && (e.keyCode < 96 || e.keyCode > 105)) {
            e.preventDefault();
        }
    });


    $('#selectall').click(function(event) {  //on click
        if(this.checked) { // check select status
            $('.checkbox1').each(function() { //loop through each checkbox
                this.checked = true;  //select all checkboxes with class "checkbox1"
            });
        }else{
            $('.checkbox1').each(function() { //loop through each checkbox
                this.checked = false; //deselect all checkboxes with class "checkbox1"
            });
        }
    });
    $('#Sselectall').click(function(event) {  //on click
        if(this.checked) { // check select status
            $("[name='status_ids[]']").each(function() { //loop through each checkbox
                this.checked = true;  //select all checkboxes with class "checkbox1"
            });
        }else{
            $("[name='status_ids[]']").each(function() { //loop through each checkbox
                this.checked = false; //deselect all checkboxes with class "checkbox1"
            });
        }
    });

    if ($('form').hasClass('new_issue')){
        trackerSla();
    }
    $('.form_tracker').change(function() {
        trackerSla();
    })

//    $('.break_time').timepicker({ 'step': 15 });
    $('.break_time').timepicker({
        timeFormat: 'H:i',
        step: 15
    });


});

function trackerSla() {
    $("select.tracker_priority").empty();
    $("select.tracker_status").empty();
    $.ajax({
        url: $('.form_tracker').attr('data-url'),
        type: 'GET',
        dataType: "json",
        data: $('#issue-form').serialize(),
        success: function(data){
            $.each(data[0], function(i, j){
                row = "<option value=\"" + j[0] + "\">" + j[1] + "</option>";
                $(row).appendTo("select.tracker_priority");
            });
            $.each(data[1], function(i, j){
                row = "<option value=\"" + j[0] + "\">" + j[1] + "</option>";
                $(row).appendTo("select.tracker_status");
            });
        }
    })
}

function send_tracker(id,tab) {
  var query_params = window.location.href.split('?');
  var link = query_params[0].split('/');
  tab = link[link.length-1]
  if(!tab)
  {
    var arry_of_url = window.location.pathname.split( '/' );
    tab=arry_of_url[arry_of_url.length - 1];
  }
  var tracker_id = $('.sla_tracker_selection').val();
  url = "/projects/"+id+"/settings/"+tab+"?tracker_id="+tracker_id
  //$.ajax({type: "get",url: url, success: function (result) {
    window.location.href = url;
  //}
  //});
}
function send_tracker_back(id,tab)
{
    window.location.href="/projects/"+id+"/settings/"+tab;
}


function validate_closing() {
    ticket_close =parseInt($('#ticket_closing').val())
    auto_close =parseInt($('#auto_close').val())

    if ((auto_close <= ticket_close) && (auto_close != 0)){
        $('.auto_close_msg').show();
        $('#flash_notice').hide();
        return false;
    }
    else  {
        $('.auto_close_msg').hide();
        return true;
    }
};

$(document).ready(function(){
    $('#auto_close').change(function (e) {
        e.preventDefault();
        ticket_close = parseInt($('#ticket_closing').val())
        auto_close = parseInt($('#auto_close').val())

        if  ((auto_close <= ticket_close) && (auto_close != 0)){
            $('.auto_close_msg').show();
            $('.mandatory_auto_close').hide();
            $('#flash_notice').hide();
        }else{
            $('.auto_close_msg').hide();
        }
        return false;
    });
});