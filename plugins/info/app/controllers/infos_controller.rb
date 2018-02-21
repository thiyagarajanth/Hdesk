class InfosController < ApplicationController
  unloadable

  def index
    @info = AdminDetail.first
    if (params[:name] || params[:mail] || params[:description]).present?
      @info = params[:id].present? ? AdminDetail.find(params[:id]) : AdminDetail.new
      @info.name = params[:name]
      @info.email =  params[:mail]
      @info.description = params[:description]
      @info.notify = params[:message]
      @info.save
    end
  end

end