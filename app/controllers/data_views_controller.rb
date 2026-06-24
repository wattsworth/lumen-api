class DataViewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_data_view, only: [:update, :destroy]
  before_action :authorize_owner, only: [:update, :destroy]

  def index
    @data_views = DataView.find_viewable(current_user)
  end

  # GET /data_views/home.json
  def home
    # return the user's home view if present
    @data_view = current_user.home_data_view
    if @data_view.nil?
      head :not_found
      return
    end
  end

  # POST /data_views.json
  def create
    @service = CreateDataView.new()
    home_view = params[:home]==true
    @service.run(data_view_params, params[:stream_ids],
      current_user, home_view)
    @data_view = @service.data_view
    render :show, status: @service.success? ? :ok : :unprocessable_content
  end

  # PATCH/PUT /data_views/1.json
  def update
    @service = StubService.new
    if @data_view.update(updatable_data_view_params)
      #set the user home view if param[:home] is set
      if(params[:home])
        current_user.update(home_data_view: @data_view)
      #otherwise clear it if this is is the current home view
      elsif(current_user.home_data_view==@data_view)
        current_user.update(home_data_view: nil)
      end
      @service.add_notice('updated data view')
      render :show, status: :ok
    else
      @service.errors = @data_view.errors.full_messages
      render :show, status: :unprocessable_content
    end
  end

  # DELETE /data_views/1.json
  def destroy
    @service = StubService.new
    @data_view.destroy
    @service.set_notice('removed data view')
    render 'helpers/empty_response', status: :ok
  end

  # PUT /data_views/map_joule_objects.json
  def map_joule_objects
    # map Joule object ID's to API ID's (see Joule route /folder/map.json for format)
    # {node_uuid, event_stream_ids, data_stream_ids, folder_ids}
    @nilm = Nilm.where(node_uuid: params[:node_uuid]).first
    if @nilm.nil?
      head :not_found and return
    end
    unless current_user.views_nilm?(@nilm)
      head :unauthorized and return
    end
    @service = MapJouleObjects.new()
    @service.run(@nilm, params[:folder_ids], params[:data_stream_ids], params[:event_stream_ids])
    ##
    @folders = @service.folders
    @event_streams = @service.event_streams
    @data_streams = @service.data_streams
  end
  
  private

  def data_view_params
    params.permit(:name, :description, :visibility, :image, :redux_json)
  end

  def updatable_data_view_params
    params.permit(:name, :description, :visibility)
  end

  def set_data_view
    @data_view = DataView.find(params[:id])
  end

  def authorize_owner
    head :unauthorized  unless @data_view.owner == current_user
  end

end
