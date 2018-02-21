module SlaReports
  module Infectors
    module Query
      module ClassMethods; end
      module InstanceMethods
      end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          def statement
            # filters clauses
            filters_clauses = []
            filters.each_key do |field|
              next if field == "subproject_id"
              v = values_for(field).clone
              next unless v and !v.empty?
              operator = operator_for(field)

              # "me" value substitution
              if %w(assigned_to_id author_id user_id watcher_id approved_by resolved_by requested_project requested_category).include?(field)
                if v.delete("me")
                  if User.current.logged?
                    v.push(User.current.id.to_s)
                    v += User.current.group_ids.map(&:to_s) if field == 'assigned_to_id'
                  else
                    v.push("0")
                  end
                end
              end

              if field == 'project_id'
                if v.delete('mine')
                  v += User.current.memberships.map(&:project_id).map(&:to_s)
                end
              end

              if field =~ /cf_(\d+)$/
                # custom field
                filters_clauses << sql_for_custom_field(field, operator, v, $1)
              elsif respond_to?("sql_for_#{field}_field")
                # specific statement
                filters_clauses << send("sql_for_#{field}_field", field, operator, v)
              else
                # field='author_id' if field == 'resolved_by'
                filters_clauses << '(' + sql_for_field(field, operator, v, queried_table_name, field) + ')'
              end
            end if filters and valid?

            if (c = group_by_column) && c.is_a?(QueryCustomFieldColumn)
              # Excludes results for which the grouped custom field is not visible
              filters_clauses << c.custom_field.visibility_by_project_condition
            end

            filters_clauses << project_statement
            filters_clauses.reject!(&:blank?)
            filters_clauses.any? ? filters_clauses.join(' AND ') : nil

          end
          private
          # Helper method to generate the WHERE sql for a +field+, +operator+ and a +value+
          def sql_for_field(field, operator, value, db_table, db_field, is_custom_filter=false)
            sql = ''
            resolved = "select journalized_id from journals where id in (select journal_id from journal_details where value in (select id from issue_statuses where name = 'resolved' and prop_key='status_id'))"
            case operator
              when "="

                if value.any?
                  case type_for(field)
                    when :date, :date_past
                      sql = date_clause(db_table, db_field, parse_date(value.first), parse_date(value.first))
                    when :integer
                      if is_custom_filter
                        sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) = #{value.first.to_i})"
                      else
                        sql = "#{db_table}.#{db_field} = #{value.first.to_i}"
                      end
                    when :float
                      if is_custom_filter
                        sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5})"
                      else
                        sql = "#{db_table}.#{db_field} BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5}"
                      end
                    else
                      if db_field == 'resolved_by'
                        sql = "#{db_table}.id IN (select issue_id from issue_details where resolved_by=('#{value.join(',')}'))"
                        #sql = User.current.admin? ? sql : "" 
                      elsif db_field == 'approved_by'
                        value = User.current.admin? ? value : [] << User.current.id
                        sql = "#{db_table}.id IN (select issue_id from ticket_approval_flows where status='approved' and user_id=('#{value.join(',')}'))"
                      elsif db_field == 'requested_project'
                        # sql = "#{db_table}.id IN (select issue_id from issue_ticket_tags where inia_project_id =('#{value.join(',')}'))"
                         issues =  IssueTicketTag.where(:inia_project_id => value ).map(&:issue_id).join(',') rescue ''
                         sql = issues.present? ? "#{db_table}.id IN (#{issues})" : "#{db_table}.id IN ('')"
                      elsif db_field == 'requested_category'
                        # p Issue.joins(:issue_ticket_tag).joins(:ticket_tag).where("ticket_tags.category_id in (?)",value)
                        category = ("tt.category_id in  (#{value.join(',')})")
                        p sql = "#{db_table}.id IN (select i.id from issues i join issue_ticket_tags it on it.issue_id = i.id
                                                  join ticket_tags tt on tt.id = it.ticket_tag_id where #{category} )"
                      else
                        sql = "#{db_table}.#{db_field} IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + ")"
                      end
                  end
                else
                  # IN an empty set
                  sql = "1=0"
                end
              when "!"
                if db_field == 'resolved_by' #&& User.current.admin?
                  sql = "#{db_table}.id IS NULL OR #{db_table}.id IN (select issue_id from issue_details where resolved_by!='' and resolved_by!=('#{value.join(',')}'))"
                elsif db_field == 'approved_by' #&& User.current.admin?
                  value = User.current.admin? ? value : [] << User.current.id
                  sql = "#{db_table}.id IS NULL OR #{db_table}.id IN (select issue_id from ticket_approval_flows where status='Approved' and issue_id not in (select issue_id from ticket_approval_flows where status='approved' and user_id=('#{value.join(',')}')))"
                elsif db_field == 'requested_project'
                  issues =  IssueTicketTag.where('inia_project_id not in (?)', value ).map(&:issue_id).join(',') rescue ''
                  sql = issues.present? ? "#{db_table}.id IN (#{issues})" : "#{db_table}.id IN ('')"
                elsif db_field == 'requested_category'
                  category = ("tt.category_id not in  (#{value.join(',')})")
                  p sql =  "#{db_table}.id IN (select i.id from issues i join issue_ticket_tags it on it.issue_id = i.id
                                                  join ticket_tags tt on tt.id = it.ticket_tag_id where #{category} )"
                elsif value.any?
                  sql = "(#{db_table}.#{db_field} IS NULL OR #{db_table}.#{db_field} NOT IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + "))"
                else
                  # NOT IN an empty set
                  sql = "1=1"
                end
              when "!*"
                if db_field == 'resolved_by' && User.current.admin?
                  sql = "#{db_table}.id IS NULL"
                  sql << " OR #{db_table}.id = ''" if is_custom_filter
                elsif db_field == 'approved_by' && User.current.admin?
                  value = User.current.admin? ? value : [] << User.current.id
                  sql = "#{db_table}.id IS NULL"
                  sql << " OR #{db_table}.id = ''" if is_custom_filter
                elsif db_field == 'requested_project'
                  sql = "#{db_table}.id IS NULL"
                  sql << " OR #{db_table}.id = ''" if is_custom_filter
                elsif db_field == 'requested_category'
                  sql = "#{db_table}.id IS NULL"
                  sql << " OR #{db_table}.id = ''" if is_custom_filter
                else
                  sql = "#{db_table}.#{db_field} IS NULL"
                  sql << " OR #{db_table}.#{db_field} = ''" if is_custom_filter
                end
              when "*"
                if db_field == 'resolved_by' && User.current.admin?
                  sql = "#{db_table}.id IS NOT NULL"
                  sql << " OR #{db_table}.id = ''" if is_custom_filter
                elsif db_field == 'approved_by' && User.current.admin?
                  value = User.current.admin? ? value : [] << User.current.id
                  sql = "#{db_table}.id IS NOT NULL"
                  sql << " OR #{db_table}.id = ''" if is_custom_filter
                elsif db_field == 'requested_project'
                  sql = "#{db_table}.id IS NOT NULL"
                  sql << " OR #{db_table}.id = ''" if is_custom_filter
                elsif db_field == 'requested_category'
                  sql = "#{db_table}.id IS NOT NULL"
                  sql << " OR #{db_table}.id = ''" if is_custom_filter
                else
                  sql = "#{db_table}.#{db_field} IS NOT NULL"
                  sql << " AND #{db_table}.#{db_field} <> ''" if is_custom_filter
                end
              when ">="
                if [:date, :date_past].include?(type_for(field))
                  sql = date_clause(db_table, db_field, parse_date(value.first), nil)
                else
                  if is_custom_filter
                    sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) >= #{value.first.to_f})"
                  else
                    sql = "#{db_table}.#{db_field} >= #{value.first.to_f}"
                  end
                end
              when "<="
                if [:date, :date_past].include?(type_for(field))
                  sql = date_clause(db_table, db_field, nil, parse_date(value.first))
                else
                  if is_custom_filter
                    sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) <= #{value.first.to_f})"
                  else
                    sql = "#{db_table}.#{db_field} <= #{value.first.to_f}"
                  end
                end
              when "><"
                if [:date, :date_past].include?(type_for(field))
                  sql = date_clause(db_table, db_field, parse_date(value[0]), parse_date(value[1]))
                else
                  if is_custom_filter
                    sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) BETWEEN #{value[0].to_f} AND #{value[1].to_f})"
                  else
                    sql = "#{db_table}.#{db_field} BETWEEN #{value[0].to_f} AND #{value[1].to_f}"
                  end
                end
              when "o"
                sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{connection.quoted_false})" if field == "status_id"
              when "c"
                sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{connection.quoted_true})" if field == "status_id"
              when "><t-"
                # between today - n days and today
                sql = relative_date_clause(db_table, db_field, - value.first.to_i, 0)
              when ">t-"
                # >= today - n days
                sql = relative_date_clause(db_table, db_field, - value.first.to_i, nil)
              when "<t-"
                # <= today - n days
                sql = relative_date_clause(db_table, db_field, nil, - value.first.to_i)
              when "t-"
                # = n days in past
                sql = relative_date_clause(db_table, db_field, - value.first.to_i, - value.first.to_i)
              when "><t+"
                # between today and today + n days
                sql = relative_date_clause(db_table, db_field, 0, value.first.to_i)
              when ">t+"
                # >= today + n days
                sql = relative_date_clause(db_table, db_field, value.first.to_i, nil)
              when "<t+"
                # <= today + n days
                sql = relative_date_clause(db_table, db_field, nil, value.first.to_i)
              when "t+"
                # = today + n days
                sql = relative_date_clause(db_table, db_field, value.first.to_i, value.first.to_i)
              when "t"
                # = today
                sql = relative_date_clause(db_table, db_field, 0, 0)
              when "ld"
                # = yesterday
                sql = relative_date_clause(db_table, db_field, -1, -1)
              when "w"
                # = this week
                first_day_of_week = l(:general_first_day_of_week).to_i
                day_of_week = Date.today.cwday
                days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
                sql = relative_date_clause(db_table, db_field, - days_ago, - days_ago + 6)
              when "lw"
                # = last week
                first_day_of_week = l(:general_first_day_of_week).to_i
                day_of_week = Date.today.cwday
                days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
                sql = relative_date_clause(db_table, db_field, - days_ago - 7, - days_ago - 1)
              when "l2w"
                # = last 2 weeks
                first_day_of_week = l(:general_first_day_of_week).to_i
                day_of_week = Date.today.cwday
                days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
                sql = relative_date_clause(db_table, db_field, - days_ago - 14, - days_ago - 1)
              when "m"
                # = this month
                date = Date.today
                sql = date_clause(db_table, db_field, date.beginning_of_month, date.end_of_month)
              when "lm"
                # = last month
                date = Date.today.prev_month
                sql = date_clause(db_table, db_field, date.beginning_of_month, date.end_of_month)
              when "y"
                # = this year
                date = Date.today
                sql = date_clause(db_table, db_field, date.beginning_of_year, date.end_of_year)
              when "~"
                sql = "LOWER(#{db_table}.#{db_field}) LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
              when "!~"
                sql = "LOWER(#{db_table}.#{db_field}) NOT LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
              else
                raise "Unknown query operator #{operator}"
            end

            return sql
          end
        end
      end

    end
  end
end