require 'application_helper'

 module ApplicationHelperForUsersPatch

   def issue_principals_check_box_tags(access_users,name, principals)
     s = ''
     principals.each do |principal|

       s << "<label>#{ check_box_tag name, principal.id, access_users.include?(principal.id) ? true : false , :id => nil } #{h principal}</label>\n"
     end
     s.html_safe
   end
 end


