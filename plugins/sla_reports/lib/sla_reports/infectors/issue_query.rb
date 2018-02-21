module SlaReports
  module Infectors
    module IssueQuery
      module ClassMethods; end
      module InstanceMethods
        def available_columns_with_sla_reports
          return @available_columns if @available_columns
          @available_columns = self.class.available_columns.dup
          @available_columns += (project ?
              project.all_issue_custom_fields :
              IssueCustomField
          ).visible.collect {|cf| QueryCustomFieldColumn.new(cf) }

            index = nil
            @available_columns.each_with_index {|column, i| index = i if column.name == :estimated_hours}
            index = (index ? index + 1 : -1)
            # insert the column after estimated_hours or at the end

            @available_columns.insert index, QueryColumn.new(:remarks,
                                                             :sortable =>  "COALESCE(SELECT remarks FROM issue_detail WHERE issue_detail.issue_id = issues.id)",
                                                             :default_order => 'desc',
                                                             :caption => "Remarks"
            )
            @available_columns.insert index, QueryColumn.new(:request_category, :sortable =>  "SELECT pc.cat_name FROM project_categories pc,issue_ticket_tags it, issues i where pc.id=it.category_id and it.issue_id=i.id",
                                                             :default_order => 'desc',
                                                             :caption => "Requested Category"
            )
            @available_columns.insert index, QueryColumn.new(:request_status, :sortable =>  "select case when CURDATE() < due_date then 'Active' when CURDATE() >= due_date then 'Expired' end as amount from issues",
                                                             :default_order => 'desc',
                                                             :caption => "Requested Status"
            )
            @available_columns.insert index, QueryColumn.new(:request_project, :sortable => "select p.name from issues i join projects p on p.id = i.project_id ",
                                                              :default_order => 'desc',
                                                              :caption => "Requested Project")
            begin
              if project.enabled_modules.map(&:name).include?('actual_sla')
              @available_columns.insert index, QueryColumn.new(:pending_time,
                                                               :sortable =>  "test",
                                                               :default_order => 'desc',
                                                               :caption => "Pending Time"
              )
              end
            rescue
            end
    
          if User.current.allowed_to?(:set_issues_private, nil, :global => true) ||
              User.current.allowed_to?(:set_own_issues_private, nil, :global => true)
            @available_columns << QueryColumn.new(:is_private, :sortable => "issues.is_private")
          end

          disabled_fields = Tracker.disabled_core_fields(trackers).map {|field| field.sub(/_id$/, '')}
          @available_columns.reject! {|column|
            disabled_fields.include?(column.name.to_s)
          }

          @available_columns
        end
        def initialize_available_filters_with_sla_reports
          principals = []
          subprojects = []
          versions = []
          categories = []
          issue_custom_fields = []

          if project
            principals += project.principals.sort
            unless project.leaf?
              subprojects = project.descendants.visible.all
              principals += Principal.member_of(subprojects)
            end
            versions = project.shared_versions.all
            categories = project.issue_categories.all
            issue_custom_fields = project.all_issue_custom_fields
          else
            if all_projects.any?
              principals += Principal.member_of(all_projects)
            end
            versions = Version.visible.where(:sharing => 'system').all
            issue_custom_fields = IssueCustomField.where(:is_for_all => true)
          end
          principals.uniq!
          principals.sort!
          principals.reject! {|p| p.is_a?(GroupBuiltin)}
          users = principals.select {|p| p.is_a?(User)}

          add_available_filter "status_id",
                               :type => :list_status, :values => IssueStatus.sorted.collect{|s| [s.name, s.id.to_s] }

          if project.nil?
            project_values = []
            if User.current.logged? && User.current.memberships.any?
              project_values << ["<< #{l(:label_my_projects).downcase} >>", "mine"]
            end
            project_values += all_projects_values
            add_available_filter("project_id",
                                 :type => :list, :values => project_values
            ) unless project_values.empty?
          end

          add_available_filter "tracker_id",
                               :type => :list, :values => trackers.collect{|s| [s.name, s.id.to_s] }
          add_available_filter "priority_id",
                               :type => :list, :values => IssuePriority.all.collect{|s| [s.name, s.id.to_s] }
          if User.current.allowed_to?(:view_resolved_tickets, nil, :global => true)
            add_available_filter 'requested_project',
                               :type => :list, :values => IniaProject.all.collect{|s| [s.name, s.id.to_s] }
          end
          if User.current.allowed_to?(:view_resolved_tickets, nil, :global => true)
            if self.project_id.nil?
              category = ProjectCategory.all.collect{|s| [s.cat_name,s.id.to_s]}
            else
              category = ProjectCategory.where(:project_id => self.project_id)
              category = category.present? ? category.collect{|s| [s.cat_name,s.id.to_s]} : ''
            end
            add_available_filter 'requested_category', :type => :list, :values => category
          end
          author_values = []
          author_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
          author_values += users.collect{|s| [s.name, s.id.to_s] }
          add_available_filter("author_id",
                               :type => :list, :values => author_values
          ) unless author_values.empty?

          # --------------- New custom Filters -------------------------------
          if User.current.allowed_to?(:view_resolved_tickets, nil, :global => true)
            add_available_filter "resolved_by",
                                 :type => :list, :values => author_values
          end
          resolved_tickets = []
          if User.current.admin?
            resolved_tickets += author_values
          else
            resolved_tickets += ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
          end

          add_available_filter "approved_by",
                               :type => :list, :values => resolved_tickets
          # --------------- New custom Filters -------------------------------

          assigned_to_values = []
          assigned_to_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
          assigned_to_values += (Setting.issue_group_assignment? ?
              principals : users).collect{|s| [s.name, s.id.to_s] }
          add_available_filter("assigned_to_id",
                               :type => :list_optional, :values => assigned_to_values
          ) unless assigned_to_values.empty?

          group_values = Group.givable.collect {|g| [g.name, g.id.to_s] }
          add_available_filter("member_of_group",
                               :type => :list_optional, :values => group_values
          ) unless group_values.empty?

          role_values = Role.givable.collect {|r| [r.name, r.id.to_s] }
          add_available_filter("assigned_to_role",
                               :type => :list_optional, :values => role_values
          ) unless role_values.empty?

          if versions.any?
            add_available_filter "fixed_version_id",
                                 :type => :list_optional,
                                 :values => versions.sort.collect{|s| ["#{s.project.name} - #{s.name}", s.id.to_s] }
          end

          if categories.any?
            add_available_filter "category_id",
                                 :type => :list_optional,
                                 :values => categories.collect{|s| [s.name, s.id.to_s] }
          end

          add_available_filter "subject", :type => :text
          add_available_filter "created_on", :type => :date_past
          add_available_filter "updated_on", :type => :date_past
          add_available_filter "closed_on", :type => :date_past
          add_available_filter "start_date", :type => :date
          add_available_filter "due_date", :type => :date
          add_available_filter "estimated_hours", :type => :float
          add_available_filter "done_ratio", :type => :integer

          if User.current.allowed_to?(:set_issues_private, nil, :global => true) ||
              User.current.allowed_to?(:set_own_issues_private, nil, :global => true)
            add_available_filter "is_private",
                                 :type => :list,
                                 :values => [[l(:general_text_yes), "1"], [l(:general_text_no), "0"]]
          end

          if User.current.logged?
            add_available_filter "watcher_id",
                                 :type => :list, :values => [["<< #{l(:label_me)} >>", "me"]]
          end

          if subprojects.any?
            add_available_filter "subproject_id",
                                 :type => :list_subprojects,
                                 :values => subprojects.collect{|s| [s.name, s.id.to_s] }
          end

          add_custom_fields_filters(issue_custom_fields)

          add_associations_custom_fields_filters :project, :author, :assigned_to, :fixed_version

          IssueRelation::TYPES.each do |relation_type, options|
            add_available_filter relation_type, :type => :relation, :label => options[:name]
          end

          Tracker.disabled_core_fields(trackers).each {|field|
            delete_available_filter field
          }
        end
        def issues(options={})
          # raise
          order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)
          obj = options[:visible] == true ? Issue : Issue.visible
          scope = obj.
              joins(:status, :project).
              where(statement).
              includes(([:status, :project] + (options[:include] || [])).uniq).
              where(options[:conditions]).
              order(order_option).
              joins(joins_for_order_statement(order_option.join(','))).
              limit(options[:limit]).
              offset(options[:offset])

          scope = scope.preload(:custom_values)
          if has_column?(:author)
            scope = scope.preload(:author)
          end
          issues = scope.all
          if has_column?(:spent_hours)
            Issue.load_visible_spent_hours(issues)
          end
          if has_column?(:relations)
            Issue.load_visible_relations(issues)
          end
          issues
        rescue ::ActiveRecord::StatementInvalid => e
          raise StatementInvalid.new(e.message)
        end
      end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable

          alias_method_chain :available_columns, :sla_reports
          alias_method_chain :initialize_available_filters, :sla_reports

        end
      end
    end
  end
end