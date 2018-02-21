# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class SysController < ActionController::Base
  before_filter :check_enabled

  def projects
    p = Project.active.has_module(:repository).order("#{Project.table_name}.identifier").preload(:repository).all
    # extra_info attribute from repository breaks activeresource client
    render :xml => p.to_xml(
                       :only => [:id, :identifier, :name, :is_public, :status],
                       :include => {:repository => {:only => [:id, :url]}}
                     )
  end

  def create_project_repository
    project = Project.find(params[:id])
    if project.repository
      render :nothing => true, :status => 409
    else
      logger.info "Repository for #{project.name} was reported to be created by #{request.remote_ip}."
      repository = Repository.factory(params[:vendor], params[:repository])
      repository.project = project
      if repository.save
        render :xml => {repository.class.name.underscore.gsub('/', '-') => {:id => repository.id, :url => repository.url}}, :status => 201
      else
        render :nothing => true, :status => 422
      end
    end
  end

  def fetch_changesets
    projects = []
    scope = Project.active.has_module(:repository)
    if params[:id]
      project = nil
      if params[:id].to_s =~ /^\d*$/
        project = scope.find(params[:id])
      else
        project = scope.find_by_identifier(params[:id])
      end
      raise ActiveRecord::RecordNotFound unless project
      projects << project
    else
      projects = scope.all
    end
    projects.each do |project|
      project.repositories.each do |repository|
        repository.fetch_changesets
      end
    end
    render :nothing => true, :status => 200
  rescue ActiveRecord::RecordNotFound
    render :nothing => true, :status => 404
  end

  protected

  def check_enabled
    User.current = nil
    unless Setting.sys_api_enabled? && params[:key].to_s == Setting.sys_api_key
      render :text => 'Access denied. Repository management WS is disabled or key is invalid.', :status => 403
      return false
    end
  end
end
