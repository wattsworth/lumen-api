# frozen_string_literal: true

# Controller for DbStreams
class DbStreamsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_stream, only: [:update, :data]
  before_action :authorize_viewer, only: [:data]
  before_action :authorize_owner, only: [:update]
  before_action :create_adapter, only: [:update, :data]
  def index
    if params[:streams].nil?
      head :unprocessable_content
      return
    end

    @streams = DbStream.find(JSON.parse(params[:streams]))
    # make sure the user is allowed to view these streams
    @streams.each do |stream|
      unless current_user.views_nilm?(stream.db.nilm)
        head :unauthorized
        return
      end
    end
  end

  def update
    @service = EditStream.new(@node_adapter)
    @service.run(@db_stream, stream_params)
    render status: @service.success? ? :ok : :unprocessable_content
  end

  def data
    @service = BuildDataset.new(@node_adapter)
    @service.run(@db_stream,params[:start_time].to_i,params[:end_time].to_i)
    unless @service.success?
      head :unprocessable_content
      return
    end
    @data = @service.data
    @legend = @service.legend
    headers["Content-Disposition"] = "attachment; filename='#{@db_stream.name}.txt'"
    render :layout=>false, :content_type => "text/plain"
  end

  private

  def stream_params
    params.permit(:name, :description, :name_abbrev, :hidden,
                  db_elements_attributes:
                    [:id, :name, :units, :default_max,
                     :default_min, :scale_factor, :display_type,
                     :offset, :plottable])
  end

  def set_stream
    @db_stream = DbStream.includes(:db_elements).find(params[:id])
    @db = @db_stream.db
    @nilm = @db.nilm
  end

  # authorization based on nilms
  def authorize_owner
    head :unauthorized  unless current_user.owns_nilm?(@nilm)
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
