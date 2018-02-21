class IniaProject  < ActiveRecord::Base
  has_many :inia_members, :foreign_key => "project_id"
  # has_many :issue_ticket_tag
  has_many :issues, :through => :issue_ticket_tags
  has_many :issue_ticket_tags
  has_many :approval_role_users, :dependent => :destroy, :foreign_key => "inia_project_id"



  def active?
    self.status == 1
  end

  def users
    # @users ||= User.active.joins(:inia_members).where("#{IniaMember.table_name}.project_id = ?", id).uniq

    # @users = User.where("select * from users u join inia_members im on im.user_id=u.id where u.status=1 and im.project_id in (#{id})")
    @users ||= User.find_by_sql("select u.id,u.firstname,u.lastname,u.login from users u join inia_members im on im.user_id=u.id where u.status=1 and im.project_id in (#{id})").uniq
  end

end