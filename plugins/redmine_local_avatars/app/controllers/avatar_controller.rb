# Redmine Local Avatars plugin
#
# Copyright (C) 2010  Andrew Chaika, Luca Pireddu
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

class AvatarController < ApplicationController
  before_filter :find_user, :except => :my_avatar_edit
  before_filter :require_login, :check_if_edit_allowed, :only => [ :update, :destroy ]
  before_filter :find_uploaded_attachment, :only => :update

  helper :attachments
  helper :avatar
  include AvatarHelper

  def show
    av = @user.attachments.where(:description => 'avatar').first
    if av
      send_file(av.diskfile, :filename => filename_for_content_disposition(av.filename),
                             :type => av.content_type,
                             :disposition => (av.image? ? 'inline' : 'attachment'))
    else
      render_404
    end
  end

  def update
    @user.attachments.where(:description => 'avatar').destroy_all

    if @uploaded_attachment.present?
      crop_values = params.values_at(:crop_w, :crop_h, :crop_x, :crop_y)
      crp = crop_image(@uploaded_attachment.diskfile, crop_values) do |f|
        @uploaded_attachment.destroy
        @user.save_attachments([{ 'file' => f, 'description' => 'avatar' }])
        @user.save
      end
      logger.error("crp is #{crp} and params is #{params[:attachment]}")
      @user.save_attachments([ params[:attachment].update(:description => 'avatar') ]) unless crp
    end

    flash[:notice] = l(:message_avatar_uploaded) if @user.save
    redirect_to_referer_or edit_my_avatar_path
  end

  def destroy
    @user.attachments.where(:description => 'avatar').destroy_all
    flash[:notice] = l(:avatar_deleted)
    render :nothing => true, :status => 200
  end

  def upload
    @attachment = Attachment.new(:file => params[:attachment][:file])
    @attachment.author = User.current
    @attachment.description = 'avatar'
    @attachment.filename = params[:filename].presence || Redmine::Utils.random_hex(16)
    @attachment.save

    respond_to { |format| format.js }
  end

  private
  def find_user
    if params[:id].present?
      @user = User.find(params[:id])
    else
      @user = User.current
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def check_if_edit_allowed
    unless User.current.admin? or @user == User.current
      deny_access
    end
  end

  def find_uploaded_attachment
    if params[:attachment].present? && params[:attachment][:token].present?
      @uploaded_attachment = Attachment.find_by_token(params[:attachment][:token])
    end
  end
end
