class TicketApprovalFlow < ActiveRecord::Base
  unloadable
  belongs_to :ticket_approval
  belongs_to :issue
  belongs_to :user
  before_update :add_approval_waiting_time

  def next
    self.class.where("id > ?", id).first
  end

  def previous
    self.class.where("id < ?", id).last
  end

  def add_approval_waiting_time
    helper = Object.new.extend(SlaTimeHelper)
    waiting_time = helper.get_approver_sla(self.issue)
    self.waiting_time = waiting_time
  end

end
