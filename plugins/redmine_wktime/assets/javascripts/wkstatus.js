$(document).ready(function(){
    var txtEntryDate;
    if(document.getElementById('divError') != null){
        if(document.getElementById('time_entry_spent_on')!=null){
            txtEntryDate = document.getElementById('time_entry_spent_on');
        }
        else{
            //get current date
            var today = new Date();
            today = today.getFullYear() + '-' + (today.getMonth()+1) + '-' + today.getDate();
            showEntryWarning(today);
        }
    }
    if(txtEntryDate!=null){
        showEntryWarning(txtEntryDate.value);
        txtEntryDate.onchange=function(){showEntryWarning(this.value)};
    }
});

function showEntryWarning(entrydate){
    var $this = $(this);
    var divID =document.getElementById('divError');
    var statusUrl = document.getElementById('getstatus_url').value;
    statusUrl = statusUrl.replace(/^http:/, 'https:');
    divID.style.display ='none';
    $.ajax({
        url: statusUrl,
        type: 'get',
        data: {startDate: entrydate},
        success: function(data){ showMessage(data,divID); },
        complete: function(){ $this.removeClass('ajax-loading'); }
    });
}

function showMessage(data,divID){
    if(data!=null && ('s'== data || 'a'== data)){
        divID.style.display = 'block';
    }
    else{
        divID.style.display ='none';
    }
}



function validate_unlock_comment(member)
{
    var comment_id = "#member-"+member+"-unlock-form"+" "+"#comment"
    var form_id = "#member-"+member+"-unlock-form"
    var error = "#member-"+member+"-unlock-form"+" "+"#unlock_error_"+member
    var role = "#member-"+member+"-unlock"
    if ($.trim($(comment_id).val()).length > 0)
    {
        $(error).hide();
        $(form_id).submit();
        $(role).show();
    }
    else
    {
        $(error).show();
    }

}

function lock_user(member)
{
    $.ajax({url:"/wktime/lock_users?user_id="+member,success:function(result){
        lock_icon =  ".icon-lock-"+member
        unlock_icon =  ".icon-unlock-"+member
        $(lock_icon).hide();
        $(unlock_icon).show();


    }});

}
function unlock_permanent(member)
{

    var row_id =  ".restrict_row_"+member
    var comment_id =  ".restrict_row_"+member+" "+"#comment"
    //var comment_id =  "#restrict_comment_"+member
    var row_comment = ".restrict_row_"+member+" "+"#restrict_comment_"+member
    var comment_val = $(row_comment).val();
    var unlock_icon = ".icon-unlock-" + member
    if ($(unlock_icon).css("display") == "inline") {
        if ($.trim($(comment_id).val()).length > 0) {
            $.ajax({url: "/wktime/unlock_permanent?user_id=" + member+"&comments="+$(comment_id).val(), success: function (result) {
                var lock_icon = ".icon-lock-" + member
                unlock_icon = ".icon-unlock-" + member
                console.log($(this).text())
                if ($(unlock_icon).css("display") == "inline") {
                    $(unlock_icon).hide();
                    $(lock_icon).show();
                    $(comment_id).val('')
                    $(row_id).hide();
                } else {
                    $(lock_icon).hide();
                    $(unlock_icon).show();
                }
            }



            });
        }
        else {

            $(row_id).show();
        }

    }
    else
    {
        $.ajax({url: "/wktime/unlock_permanent?user_id=" + member, success: function (result) {
            var lock_icon = ".icon-lock-" + member
            var unlock_icon = ".icon-unlock-" + member
            console.log($(this).text())
            if ($(unlock_icon).css("display") == "inline") {
                $(unlock_icon).hide();
                $(lock_icon).show();
            } else {
                $(lock_icon).hide();
                $(unlock_icon).show();
            }
        }
        });


    }


}
function unlock_permanent_cancel(member) {
    var row_id =  ".restrict_row_"+member
    $(row_id).hide();
    var comment_id =  ".restrict_row_"+member+" "+"#comment"
    $(comment_id).val("");
}

function check(check_status)
{

    var status_true =$(".approval-checkbox_true:checked").size();
    var checked = $(".approval-checkbox:checked")
    var check_box_checked_size = $(".approval-checkbox:checked").size();

    var row_value_arry=[];
    var array_row_value_arry=[];
    $('.approval-checkbox:checked').each( function( index, element ){
        var id = $(this).attr("rowvalue");
        var row_class=".row_"+id;
        var row_value_arry=[];
        var row_values = $(row_class);
        for (var i = 0; i < row_values.length; i++) {
            if (!row_values[i].value=="")
            {
                row_value_arry.push(row_values[i]);
            }
        }
        //alert(row_value_arry);
        if (row_value_arry !='')
        {

            array_row_value_arry.push('true')
        }
        else
        {

            array_row_value_arry.push('false')
        }
        // alert(array_row_value_arry)

    });
    var status_false =$(".approval-checkbox_false:checked").size();
//alert(array_row_value_arry);
    var test = jQuery.inArray("false", array_row_value_arry)

    //alert(test);

    if(!(test > -1) && check_box_checked_size > 0)
    {
        $("#wktime_approve").prop('disabled', false);
        $("#wktime_reject").prop('disabled', false);

    }
    else
    {
        $("#wktime_approve").prop('disabled', true);
        $("#wktime_reject").prop('disabled', true);

    }
    if(status_false == 0 && status_true > 0 && $("#wktime_unapprove").size() > 0) {
        $("#wktime_unapprove").prop('disabled', false);
        $("#wktime_reject").prop('disabled', true);
        $("#wktime_approve").prop('disabled', true);
    }
    else if(status_true == 0 && status_false > 0)
    {
        //$("#wktime_approve").prop('disabled', false);
        //$("#wktime_reject").prop('disabled', false);

        $("#wktime_unapprove").prop('disabled', true);

    }
    else if(status_true > 0 && status_false > 0)
    {
        $("#wktime_approve").prop('disabled', true);
        $("#wktime_reject").prop('disabled', true);

        $("#wktime_unapprove").prop('disabled', true);

    }
    else
    {

        $("#wktime_unapprove").prop('disabled', true);
    }

    if(status_false == 0)
    {
        // alert("yes")

    }

}

function check_l2(id)

{
    var status_true =$(".approval-checkbox_true:checked").size();
    //var status_false =$(".approval-checkbox_false:checked").size();
    if(status_true > 0 && $("#wktime_approve").size() > 0) {

        $("#wktime_approve").prop('disabled', false);
    }
    else
    {
        $("#wktime_approve").prop('disabled', true);
    }

}
$( "#wktime_unapprove" ).on( "click", function() {
    $("form#wktime_edit").append('<input name= "wktime_unapprove" value="true" style="display:none" />');
});
$( "#wktime_reject" ).on( "click", function() {
    alert("hello ");
    $("form#wktime_reject").append('<input name= "wktime_reject" value="true" style="display:none" />');
});


/* Script for L3 approval */

function check_l3(id)
{
    var status_true =$(".approval-checkbox_true:checked").size();
    var all_checks =$(".approval-checkbox").size();
    var status_false =$(".approval-checkbox_false:checked").size();
    var status_true_false =$(".approval-checkbox_true_false:checked").size();
    var total_checks = status_false + status_true + status_true_false
    var home_l2_status =$(".approve_status_home_l2:checked").size();


    if (status_false == 0 &&  status_true == 0 && status_true_false == 0) {
//         alert(1)
        $("#wktime_approve_l3").prop('disabled', true);
        $("#wktime_reject_l3").prop('disabled', true);
        $("#wktime_unapprove_l3").prop('disabled', true);

    }
    else if (status_false == 0 &&  status_true == 0 && status_true_false > 0) {
//           alert(2)
        $("#wktime_approve_l3").prop('disabled', false);
        $("#wktime_reject_l3").prop('disabled', false);
        $("#wktime_unapprove_l3").prop('disabled', false);
    }
    else if (status_false == 0 &&  status_true > 1 && status_true_false == 0) {
//            alert(3)
        $("#wktime_approve_l3").prop('disabled', true);
        $("#wktime_reject_l3").prop('disabled', true);
        $("#wktime_unapprove_l3").prop('disabled', false);
    }
    else if (status_false > 0 &&  status_true == 0 && status_true_false == 0) {
//            alert(4)
        $("#wktime_approve_l3").prop('disabled', false);
        $("#wktime_reject_l3").prop('disabled', false);
        $("#wktime_unapprove_l3").prop('disabled', true);
    }

    else if (status_false > 0 &&  status_true > 0 && status_true_false == 0) {
//        alert(5)
        $("#wktime_approve_l3").prop('disabled', false);
        $("#wktime_reject_l3").prop('disabled', false);
        $("#wktime_unapprove_l3").prop('disabled', true);
    }
    else if (status_false > 0 &&  status_true == 0 && status_true_false > 0) {
//            alert(6)
        $("#wktime_approve_l3").prop('disabled', false);
        $("#wktime_reject_l3").prop('disabled', false);
        $("#wktime_unapprove_l3").prop('disabled', false);
    }
    else if (status_false == 0 &&  status_true > 0 && status_true_false > 0) {
//            alert(7)
        $("#wktime_approve_l3").prop('disabled', true);
        $("#wktime_reject_l3").prop('disabled', true);
        $("#wktime_unapprove_l3").prop('disabled', true);
    }
    else if (status_false == 0 &&  status_true > 0 && status_true_false > 0) {
//            alert(8)
        $("#wktime_approve_l3").prop('disabled', true);
        $("#wktime_reject_l3").prop('disabled', true);
        $("#wktime_unapprove_l3").prop('disabled', true);
    }
    else if (status_false > 0 &&  status_true > 0 && status_true_false > 0) {
//            alert(9)
        $("#wktime_approve_l3").prop('disabled', false);
        $("#wktime_reject_l3").prop('disabled', false);
        $("#wktime_unapprove_l3").prop('disabled', false);
    }

    else {
//            alert(10)
        $("#wktime_approve_l3").prop('disabled', true);
        $("#wktime_reject_l3").prop('disabled', true);
        $("#wktime_unapprove_l3").prop('disabled', false);
    }
    if(total_checks == all_checks)
    {
        $("#selectall_l3").prop('checked', true);
    }
    else
    {
        $("#selectall_l3").prop('checked', false);
    }


}

/* Script for home L2 approval */

function check_home_l2(id)
{
    var status_true =$(".approval-checkbox_true:checked").size();
    var status_true_false =$(".approval-checkbox_true_false:checked").size();
    var all_checks =$(".approval-checkbox").size();
    var status_false =$(".approval-checkbox_false:checked").size();
    var total_checks = status_false + status_true + status_true_false
    var l3_staus =$(".approve_status_l3:checked").size();

    if(l3_staus <= 0) {

        if (status_false == 0 &&  status_true == 0 && status_true_false == 0) {
            // alert(1)
            $("#wktime_approve_home_l2").prop('disabled', true);
            $("#wktime_reject_home_l2").prop('disabled', true);
            $("#wktime_unapprove_home_l2").prop('disabled', true);

        }
        else if (status_false == 0 &&  status_true == 0 && status_true_false > 0) {
//            alert(2)
            $("#wktime_approve_home_l2").prop('disabled', false);
            $("#wktime_reject_home_l2").prop('disabled', false);
            $("#wktime_unapprove_home_l2").prop('disabled', false);
        }
        else if (status_false == 0 &&  status_true > 1 && status_true_false == 0) {
//            alert(3)
            $("#wktime_approve_home_l2").prop('disabled', true);
            $("#wktime_reject_home_l2").prop('disabled', true);
            $("#wktime_unapprove_home_l2").prop('disabled', false);
        }
        else if (status_false > 0 &&  status_true == 0 && status_true_false == 0) {
//            alert(4)
            $("#wktime_approve_home_l2").prop('disabled', false);
            $("#wktime_reject_home_l2").prop('disabled', false);
            $("#wktime_unapprove_home_l2").prop('disabled', true);
        }

        else if (status_false > 0 &&  status_true > 0 && status_true_false == 0) {
            alert(5)
            $("#wktime_approve_home_l2").prop('disabled', false);
            $("#wktime_reject_home_l2").prop('disabled', false);
            $("#wktime_unapprove_home_l2").prop('disabled', true);
        }
        else if (status_false > 0 &&  status_true == 0 && status_true_false > 0) {
//            alert(6)
            $("#wktime_approve_home_l2").prop('disabled', false);
            $("#wktime_reject_home_l2").prop('disabled', false);
            $("#wktime_unapprove_home_l2").prop('disabled', false);
        }
        else if (status_false == 0 &&  status_true > 0 && status_true_false > 0) {
//            alert(7)
            $("#wktime_approve_home_l2").prop('disabled', true);
            $("#wktime_reject_home_l2").prop('disabled', true);
            $("#wktime_unapprove_home_l2").prop('disabled', true);
        }
        else if (status_false == 0 &&  status_true > 0 && status_true_false > 0) {
//            alert(8)
            $("#wktime_approve_home_l2").prop('disabled', true);
            $("#wktime_reject_home_l2").prop('disabled', true);
            $("#wktime_unapprove_home_l2").prop('disabled', true);
        }
        else if (status_false > 0 &&  status_true > 0 && status_true_false > 0) {
//            alert(9)
            $("#wktime_approve_home_l2").prop('disabled', false);
            $("#wktime_reject_home_l2").prop('disabled', false);
            $("#wktime_unapprove_home_l2").prop('disabled', false);
        }

        else {
//            alert(10)
            $("#wktime_approve_home_l2").prop('disabled', true);
            $("#wktime_reject_home_l2").prop('disabled', true);
            $("#wktime_unapprove_home_l2").prop('disabled', false);
        }

    }
    else
    {
        $("#wktime_approve_home_l2").prop('disabled', true);
    }

    if (total_checks == all_checks) {
        $("#selectall_home_l2").prop('checked', true);
    }
    else {
        $("#selectall_home_l2").prop('checked', false);
    }



}

$(document).ready(function() {
    $('#selectall_l3').click(function(event) {  //on click
        if(this.checked) { // check select status
            $('.approval-checkbox').each(function() { //loop through each checkbox
                this.checked = true;  //select all checkboxes with class "checkbox1"
            });
        }else{
            $('.approval-checkbox').each(function() { //loop through each checkbox
                this.checked = false; //deselect all checkboxes with class "checkbox1"
            });
        }
        check_l3("test")

    });

    $('#selectall_home_l2').click(function(event) {  //on click
        if(this.checked) { // check select status
            $('.approval-checkbox').each(function() { //loop through each checkbox
                this.checked = true;  //select all checkboxes with class "checkbox1"
            });
        }else{
            $('.approval-checkbox').each(function() { //loop through each checkbox
                this.checked = false; //deselect all checkboxes with class "checkbox1"
            });
        }
        check_home_l2("test")

    });

});


function showNotes() {

    //$("form#wktime_edit").append('<input name= "wktime_reject" value="true" style="display:none" />');
    var rejectBtn = $( 'input[name="wktime_reject"]' );
    var width = 300;
    var height = 200;
    var posX = 0;
    var posY = 0;
    posX = $(rejectBtn).offset().left - $(document).scrollLeft() - width + $(rejectBtn).outerWidth();
    posY = $(rejectBtn).offset().top - $(document).scrollTop() + $(rejectBtn).outerHeight();
    $("#notes-dlg").dialog({width:width, height:height ,position:[posX, posY]});
    $( "#notes-dlg" ).dialog( "open" );
    //return false so the form is not posted
    return false;
}