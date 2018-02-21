module DashboardHelper

	def get_trackers_for_project (project)
		total_count = Issue.visible.where(:project_id => project).count
		open_count =  Issue.visible.open.where(:project_id => project).count
		return open_count,total_count
  end

  def get_approval_statuses
    IssueSlaStatus.where(:approval_sla => true).map(&:issue_status_id).uniq
  end
end
