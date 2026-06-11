# frozen_string_literal: true
class DbElementsController < ApplicationController
  before_action :authenticate_user!




  def data
    req_elements = DbElement.find(JSON.parse(params[:elements]))
    # make sure the user is allowed to view these elements
    req_elements.each do |elem|
      unless current_user.views_nilm?(elem.db_stream.db.nilm)
        head :unauthorized
        return
      end
    end
    # make sure the time range makes sense
    start_time = (params[:start_time].to_i unless params[:start_time].nil?)
    end_time = (params[:end_time].to_i unless params[:end_time].nil?)
    #requested resolution (leave blank for max possible)
    resolution = (params[:resolution].to_i unless params[:resolution].nil?)
    # padding: percentage of data to retrieve beyond start|end
    padding = params[:padding].nil? ? 0 : params[:padding].to_f


    # retrieve the data for the requested elements
    @service = LoadElementData.new

    #if start and end are specified, calculate padding
    if !start_time.nil? && !end_time.nil?
      actual_start = (start_time - (end_time-start_time)*padding).to_i
      actual_end   = (end_time   + (end_time-start_time)*padding).to_i
      @service.run(req_elements, actual_start, actual_end, resolution)
      @start_time = start_time
      @end_time = end_time
    #otherwise let the service determine the start/end automatically
    else
      @service.run(req_elements, start_time, end_time, resolution)
      @start_time = @service.start_time
      @end_time = @service.end_time
    end

    render status: @service.success? ? :ok : :unprocessable_content
  end
end
