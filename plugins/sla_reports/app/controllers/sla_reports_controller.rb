class SlaReportsController < ApplicationController
  unloadable

  default_search_scope :issues
  # before_filter :authorize, :except => [:index]
  # before_filter :find_optional_project, :only => [:index]
  accept_rss_auth :index
  accept_api_auth :index


  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :journals
  helper :projects
  include ProjectsHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :issue_relations
  include IssueRelationsHelper
  helper :watchers
  include WatchersHelper
  helper :attachments
  include AttachmentsHelper
  helper :queries
  include QueriesHelper
  helper :repositories
  include RepositoriesHelper
  helper :sort
  include SortHelper
  include IssuesHelper
  helper :timelog
  include Redmine::Export::PDF
  include SlaReportsHelper

  def index
    retrieve_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a
    @project = Project.find(params[:project_id])
    @query.project_id = @project.id
    user_request_validity
    #request_validity
    # projmem = @project.members.order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC")
    # @members=projmem.collect{|m| [ m.name, m.user_id ] }
    @issues = []
    @request=[]
     # raise
    
    if @query.valid? && params['period_type'].present?
      @limit = per_page_option
      @issue_count = @query.issue_count
      @issue_pages = Paginator.new @issue_count, @limit, params['page']
      @offset ||= @issue_pages.offset
      get_filter_results(params)

      respond_to do |format|
        format.html {
          render 'index'
           }
        format.api  {
          Issue.load_visible_relations(@issues) if include_in_api_response?('relations')
        }
      end
    else
      respond_to do |format|
        format.html { render 'index', :layout => !request.xhr? }
        format.any(:atom, :csv, :pdf) { render(:nothing => true) }
        format.api { render_validation_errors(@query) }
      end
    end
    # send_file file_path, :type=>'text/csv'
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def get_not_met_sla_tickets
    entry = TimeEntry.where(:issue_id => params[:issue_id]).group('issue_id').sum('hours').values[0]
    t_hours = entry.to_f + params[:hours].to_f
    issue = Issue.find(params[:issue_id])
    sla_hours = issue.issue_sla.to_f
    detail = IssueDetail.find_by_issue_id(params[:issue_id])
    result = []
    remark = detail.present? ? detail.remarks : ''
    if (issue.status.name == 'Resolved' || issue.status.name == 'Closed') && issue.issue_sla.present? && sla_hours < t_hours
      status = false
    else
      status = true
    end
    result << [status, remark]
    render :json => {status:  result}
  end

  def get_not_met_sla_tickets_on_load
    status = false
    detail = IssueDetail.find_by_issue_id(params[:issue_id])
    status = detail.remarks.present? if detail.present?
    result = []
    if status
      result << [status, detail.remarks]
    else
      result << [status, '']
    end
    render :json => {status:  result}
  end


  def request_validity
    project=Project.find(params[:project_id])
    retrieve_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a
    @query.column_names = [:author, :subject, :created_on, :due_date, :request_status ]
    get_request_validity_records(params) if params[:report]=="true"
    respond_to do |format|
      format.html { redirect_to "/projects/#{project.id}/sla_reports?tab=request_validity&request=#{params[:request]}&from1=#{params[:from1]}&to1=#{params[:to1]}&employee_id=#{params[:employee_id]}&request_user_id=#{params[:request_user_id]}" }
      format.api  {
        Issue.load_visible_relations(@issues) if include_in_api_response?('relations')
      }
      #format.atom { render_feed(@issues, :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}") }
      #format.csv  { send_data(query_to_csv(@issues, @query, params), :type => 'text/csv; header=present', :filename => 'issues.csv') }
      #format.pdf  { send_data(issues_to_pdf(@issues, project, @query), :type => 'application/pdf', :filename => 'issues.pdf') }
    end
  end

  def user_request_validity
    get_current_user_request(params)
  end



  def user_rating
    retrieve_date_range(params[:period1],params[:rate_from],params[:rate_to],params[:period_type])
    @project = Project.find(params[:project_id])
    @result = []
    user_ids = []
    if params[:rate_user_id].present?
      user_ids << params[:rate_user_id]
    else
      user_ids = TeamProfile.where(project_id: @project.id, display: true).order('name').map(&:user_id)
    end
    user_ids.each do |user_id|
      rating = UserRating.where("project_id = #{@project.id} and rated_for = #{user_id} and created_at >='#{@from}' and created_at <= '#{@to}'"  )
      total = rating.sum(:rating) rescue 0
      avg = total.to_f/rating.count.to_f
      avg = avg.present? ? avg.round(2) : 0
      name = TeamProfile.find_by_user_id(user_id).name
      @result << {:name => name, :count => rating.count, :avg => avg, :user_id => user_id, :project_id => @project.id}
    end
    render 'index', :tab => 'user_rating'
  end





end
