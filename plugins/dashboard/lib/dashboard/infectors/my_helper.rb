module Dashboard
	module Infectors
		module MyHelper

			def self.included(base)
				base.class_eval do
				
					def issueswaitingforapproval
            helper = Object.new.extend(DashboardHelper)
    					Issue.visible.
    					  where(:assigned_to_id => User.current.id,:status_id => helper.get_approval_statuses).
    					  limit(10).
    					  includes(:status, :project, :tracker).
    					  order("#{Issue.table_name}.updated_on DESC").
    					  all
 					end				
				end
						
			end
		end
	end
end

