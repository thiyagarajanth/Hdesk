$( document ).ready(function() {

   $('form.edit_user input, select').each(
        function(index){
            var input = $(this);
            var id = $(this).attr("id");
            if(id == "user_login" || id == "user_firstname" || id == "user_lastname" || id == "user_mail" || id == "user_official_info" || id == "user_auth_source_id" )
            {
                $(this).prop( "disabled", true );
                if(id=="user_official_info")
                {
                   if(id == "user_official_info")
                   {
                       var employee_id = $(this).val();
                       var hidden_ele = "<input id='user_official_info' name='user_official_info' required='required' type='hidden' value="+employee_id+" >"
                       $("form.edit_user").append(hidden_ele);

                   }
$(this).find('#user_official_info').attr("type","hidden")

                }
            }
        }
    );



if( $('div#content a.icon-add').attr("href") ==  "/users/new" ) {
//    var href_for_new_user = $('div#content a.icon-add').attr("href");

        $('div#content a.icon-add').hide();
        $('div#content tr.user td.buttons a.icon-del').hide();

}
    if ($('div#content a.icon-del').parent().find('a').first().text() == "Profile") {
        $('div#content a.icon-del').hide();
    }
}); 