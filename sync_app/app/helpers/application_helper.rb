module ApplicationHelper

  def request_remainder
    ActionMailer::Base.raise_delivery_errors = true
    alert1 = RequestRemainder.where("validity = ?", Date.today)
    alert2 = RequestRemainder.where("validity = ?", Date.today + 2.day)
    alert3 = RequestRemainder.where("validity = ?", Date.today + 7.day)
    alerts = []
    alerts << alert1
    alerts << alert2
    alerts << alert3
    alerts.each_with_index do |alert, i|
      alert.each do |mail|
        trigger_remainder(mail,i)
      end
    end
    #RequestRemainder.where("validity < ?", Date.today).delete_all
    ActionMailer::Base.raise_delivery_errors = false
  end

  def retry_remainder
    ActionMailer::Base.raise_delivery_errors = true
    alert1 = RequestRemainder.where("validity = ? and mail_status=false and retry_attempts < 4", Date.today)
    alert2 = RequestRemainder.where("validity = ? and mail_status=false and retry_attempts < 4", Date.today + 2.day)
    alert3 = RequestRemainder.where("validity = ? and mail_status=false and retry_attempts < 4", Date.today + 7.day)
    alerts = []
    alerts << alert1
    alerts << alert2
    alerts << alert3
    alerts.each_with_index do |alert, i|
      alert.each do |mail|
        trigger_remainder(mail,i)
      end
    end
    ActionMailer::Base.raise_delivery_errors = false
  end

  def trigger_remainder(mail,i)
    author = mail.issue.author_id
    tag = mail.issue.issue_ticket_tag
    new_request = RequestRemainder.where("validity > ? and user_id=? and ticket_tag_id=?",Date.today, author, tag.id)
    if !new_request.present?
      begin
        if i==0
          Mailer.admin_remainder(mail.issue).deliver
        else
          Mailer.request_remainder_mail(mail.issue).deliver
        end
        mail.update_attributes(:error_info => '', :mail_status => true,retry_attempts: 0)
      rescue Net::SMTPAuthenticationError, Net::SMTPServerBusy, Net::SMTPSyntaxError, Net::SMTPFatalError, Net::SMTPUnknownError => e
        mail.update_attributes(:error_info => e.message, :mail_status => false,retry_attempts: (mail.retry_attempts+1))
      end
    else
    end
  end

  def send_job_status_notification(status)
    project_ids =  RequestRemainder.all.map(&:project_id).uniq.compact
    project_ids.each do |dept|
      begin
        Mailer.job_notification(dept, status).deliver
      rescue  Exception => e
        logger.warn "email delivery error = #{e}"
      end
    end
  end

end
