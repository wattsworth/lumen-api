# frozen_string_literal: true

# controller for NILM objects
class NilmsController < ApplicationController
  before_action :authenticate_user!, except: [:create]
  before_action :set_nilm, only: [:update, :show, :destroy]
  before_action :authorize_viewer, only: [:show]
  before_action :authorize_owner, only: [:update]
  before_action :authorize_admin, only: [:destroy]
  before_action :create_adapter_from_nilm, only: [:show]

  # GET /nilms.json
  def index
    #just the NILM info, no database or joule modules
    @nilms = current_user.retrieve_nilms_by_permission
  end

  def show
    #render the database and joule modules
    @role = current_user.get_nilm_permission(@nilm)
    #request new information from the NILM
    if params[:refresh]
      @service = UpdateNilm.new(@node_adapter)
      @service.run(@nilm)
      render status: @service.success? ? :ok : :unprocessable_content
    else
      @service = StubService.new
    end
  end

  # POST /nilms.json
  def create
    if User.count == 0
      # If there are no users then create a user from the parameters
      @service = AddNilmByUser.new
    else
      # Otherwise an auth_key is required to identify the user
      @service = AddNilmByKey.new
    end
    @service.run(params, request.remote_ip)
    errors = @service.warnings+@service.errors
    if errors.empty?
      render plain: "ok"
    else
      render plain: errors.join(", "), status: :unprocessable_content
    end
  end

  # PATCH/PUT /nilms/1
  # PATCH/PUT /nilms/1.json
  def update
    #update both the NILM and the Db models
    @service = StubService.new
    # redundant since the user must be an owner...
    @role = current_user.get_nilm_permission(@nilm)
    if @nilm.update(nilm_params) && @db.update(db_params)
      @service.add_notice('Installation Updated')
      render :show, status: :ok
    else
      @service.errors = @nilm.errors.full_messages +
                        @db.errors.full_messages
      render :show, status: :unprocessable_content
    end
  end

  # DELETE /nilms/1.json
  def destroy
    @service = StubService.new
    @db = @nilm.db
    DbStream.where(db_id: @db.id).each do |stream|
      DbElement.where(db_stream_id: stream.id).delete_all
    end
    DbStream.where(db_id: @db.id).delete_all
    DbFolder.where(db_id: @db.id).delete_all
    EventStream.where(db_id: @db.id).delete_all
    @nilm.destroy
    @service.set_notice('removed nilm')
    render 'helpers/empty_response', status: :ok
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_nilm
      @nilm = Nilm.find(params[:id])
      @db = @nilm.db
    end

    # Never trust parameters from the scary internet,
    # only allow the white list through.
    def nilm_params
      params.permit(:name, :description, :url)
    end
    def db_params
      params.permit(:max_points_per_plot, :max_events_per_plot, :url)
    end

    #authorization based on nilms
    def authorize_admin
      head :unauthorized  unless current_user.admins_nilm?(@nilm)
    end
    def authorize_owner
      head :unauthorized  unless current_user.owns_nilm?(@nilm)
    end
    def authorize_viewer
      head :unauthorized  unless current_user.views_nilm?(@nilm)
    end

    def create_adapter_from_nilm
      @node_adapter = NodeAdapterFactory.from_nilm(@nilm)
      if @node_adapter.nil?
        @service = StubService.new
        @service.add_error("Cannot contact installation")
        render 'helpers/empty_response', status: :unprocessable_content
      end
    end
end
