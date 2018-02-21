class RequestRemainder < ActiveRecord::Base
  unloadable
  belongs_to :issue
  belongs_to :ticket_tag
  belongs_to :user
  belongs_to :project

  validates :validity, :presence => true
  validates :project_id, :presence => true
  validates :issue_id, :presence => true
  validates :user_id, :presence => true
  validates :ticket_tag_id, :presence => true


  def migrate_missing_report
     count =  RequestRemainder.count
    issues = Issue.find_by_sql("select i.* from issues i join issue_ticket_tags as it on issue_id=i.id join ticket_tags tt on tt.id=it.ticket_tag_id where  tt.validity > 0  and i.id  not in(select distinct issue_id from request_remainders) and i.due_date is not NULL order by i.id asc;")
    issues.each do |rec|
      tag = rec.issue_ticket_tag rescue nil
      next unless tag
      if tag.present? && tag.ticket_tag.present?
        tag = tag.ticket_tag
        validity = tag.validity.present? ? tag.validity : 0
        if validity > 0 && rec.due_date.present?
          if rec.access_users.present?
            rec.access_users.each do |each_user|
            request = RequestRemainder.find_or_initialize_by_issue_id_and_user_id(rec.id, each_user.to_i)
            request.validity = rec.due_date
            request.ticket_tag_id = tag.id
            request.project_id = rec.project_id
            request.save
            end
          else
            request = RequestRemainder.find_or_initialize_by_issue_id_and_user_id(rec.id, rec.author_id)
            request.validity = rec.due_date
            request.ticket_tag_id = tag.id
            request.project_id = rec.project_id
            request.save
          end
        end
      end
    end
    p '==== after migration report count ===='
    p [count, RequestRemainder.count]
  end

end