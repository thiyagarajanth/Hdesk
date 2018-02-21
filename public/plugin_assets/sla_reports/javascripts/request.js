$(document).ready(function(){
    //$('.enableRadio').prop("disabled", false);
    $('#tab').dataTable({  
      
      dom: 'Blfrtip',
      buttons: ['csv'],
     
    });

   
    $('.autofill').select2({
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
       
        console.log(myResults);
        console.log(44444444444444)
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
    
  

 // var a =  $('#request_user_id').attr('data-user_id');
 // var user_info = a.split(/\s+/);
 // if (user_info[0] > 0) {
 //    setTimeout(function(){
 //        id = user_info[0] 
 //        user_info.shift()
 //       $('#request_user_id').select2("data", { id: id, text: user_info.join(" ")  });
 //    }, 500);
   
 // }else{ 
 //  $('#request_user_id').select2("data", { id: 0, text: 'All Users'})
 //   }

 //    $('.enableRadio').prop("disabled", false);
 //    $('.hideRadio').prop("disabled", true);
    
 //    $('input[name="userfield"]').click(function() {
 //        var field_class = $(this).attr('class');
 //        console.log('================')
 //        console.log($(this).val())
 //        if ($(this).val() === 'on') {
 //          $('#request_user_id').select2('disable');
 //          $('#s2id_request_user_id').find('span').first().text('All User');
 //          $('#request_user_id').select2("data","");
 //          $('.id_field').removeProp("disabled",false);
 //        }else {
 //          $('#employee_id').attr("value","");
 //          $('#employee_id').attr("disabled",true);
 //          $('#request_user_id').select2('enable');
 //        }



 //    });

  //for implementing datatables plugin in request validity report
    

});
