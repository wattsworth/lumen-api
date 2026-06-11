class AnnotationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_stream
  before_action :create_adapter
  before_action :authorize_owner, except: [:index]


  # GET /stream/:stream_id/annotations.json
  def index
    @service = StubService.new
    begin
      @annotations = @node_adapter.get_annotations(@db_stream)
    rescue RuntimeError => e
      @service.add_error("Cannot retrieve annotations [#{e}]")
      render 'helpers/empty_response', status: :unprocessable_content
    end
  end

  # POST /annotations.json
  def create
    annotation = Annotation.new
    annotation.title = params[:title]
    annotation.content = params[:content]
    annotation.db_stream = @db_stream
    annotation.start_time = params[:start].to_i
    unless params[:end].nil?
      annotation.end_time = params[:end].to_i
    end

    @service = StubService.new
    begin
      @node_adapter.create_annotation(annotation)
    rescue RuntimeError => e
      @service.add_error("Cannot create annotation [#{e}]")
      render 'helpers/empty_response', status: :unprocessable_content and return
    end
    @annotations = [annotation]
    render :index
  end

  # PATCH/PUT /annotations/1.json
  def update
    @service = StubService.new
    begin
      annotation = @node_adapter.edit_annotation(params[:id],
                                                 params[:title],
                                                 params[:content],
                                                 @db_stream)
    rescue RuntimeError => e
      @service.add_error("Cannot update annotation [#{e}]")
      render 'helpers/empty_response', status: :unprocessable_content and return
    end
    @annotations = [annotation]
    render :index
  end

  # DELETE /annotations/1.json
  def destroy
    annotation = Annotation.new
    annotation.db_stream = @db_stream
    annotation.id = params[:id].to_i
    @service = StubService.new
    begin
      @node_adapter.delete_annotation(annotation)
    rescue RuntimeError => e
      @service.add_error("Cannot delete annotation [#{e}]")
      render 'helpers/empty_response', status: :unprocessable_content and return
    end
    render 'helpers/empty_response'
  end

  private

  def set_stream
    @db_stream = DbStream.find(params[:db_stream_id])
    @db = @db_stream.db
    @nilm = @db.nilm
  end

  # authorization based on nilms
  def authorize_owner
    head :unauthorized  unless current_user.owns_nilm?(@nilm)
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
