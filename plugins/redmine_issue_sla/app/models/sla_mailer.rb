class SlaMailer < ActionMailer::Base
  layout 'mailer'
  helper :application
  include Redmine::I18n

  def sendResponseEmail(loginuser,issue,response)
    user = issue.author
    set_language_if_valid(user.language)
      subject="Responded to your issue"
      body= ''

    body +="\n #{l(:field_name)} : #{user.firstname} #{user.lastname} \n"
    body +="\n Issue : #{issue.subject} \n"
    body +="\n Issue created on : #{issue.created_on.localtime} \n"
    body += response.comment
    body +="\n"
    mail :from => loginuser.mail,:to => user.mail, :subject => subject,:body => body
  end

end
