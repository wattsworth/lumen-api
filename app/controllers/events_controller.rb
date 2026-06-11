class EventsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_stream, except: :data
  before_action :authorize_viewer, except: :data
  before_action :create_adapter, except: :data

  def show

  end

  def update
    @service = EditEventStream.new(@node_adapter)
    @service.run(@event_stream, stream_params)
    render status: @service.success? ? :ok : :unprocessable_content
  end

  def data
    # streams parameters is a JSON array
    # [{id, filter},{id, filter},...]
    stream_param = JSON.parse(params[:streams])
    req_streams = stream_param.map do |param|
      { stream: EventStream.find(param["id"]),
        filter: param["filter"],
        tag: param["tag"]
      }
    end
    # make sure the user is allowed to view these elements
    req_streams.each do |req_stream|
      unless current_user.views_nilm?(req_stream[:stream].db.nilm)
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
    @service = ReadEvents.new

    #if start and end are specified, calculate padding
    if !start_time.nil? && !end_time.nil?
      actual_start = (start_time - (end_time-start_time)*padding).to_i
      actual_end   = (end_time   + (end_time-start_time)*padding).to_i
      @service.run(req_streams, actual_start, actual_end)
      @start_time = start_time
      @end_time = end_time
      #otherwise let the service determine the start/end automatically
    else
      @service.run(req_streams, start_time, end_time)
      @start_time = @service.start_time
      @end_time = @service.end_time
    end
    render status: @service.success? ? :ok : :unprocessable_content

  end

  private

  def stream_params
    params.permit(:name, :description)
  end

  def set_stream
    @event_stream = EventStream.find(params[:id])
    @db = @event_stream.db
    @nilm = @db.nilm
  end

  def authorize_viewer
    head :unauthorized  unless current_user.views_nilm?(@nilm)
  end

  def create_adapter
    @node_adapter = NodeAdapterFactory.from_nilm(@nilm)
    if @node_adapter.nil?
      @service = StubService.new
      @service.add_error("Cannot contact installation")
      render 'helpers/empty_response', status: :unprocessable_content
    end
  end

end
