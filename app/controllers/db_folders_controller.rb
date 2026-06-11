# frozen_string_literal: true

# Controller for DbFolders
class DbFoldersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_folder, only: [:show, :update]
  before_action :authorize_viewer, only: [:show]
  before_action :authorize_owner, only: [:update]
  before_action :create_adapter, only: [:update]

  # GET /db_folders.json
  def show; end

  # PATCH/PUT /db_folders/1.json
  # TODO: create info stream on folders on edit
  def update
    @service = EditFolder.new(@node_adapter)
    @service.run(@db_folder, folder_params)
    render status: @service.success? ? :ok : :unprocessable_content
  end

  private

  def folder_params
    params.permit(:name, :description, :hidden)
  end

  def set_folder
    @db_folder = DbFolder.includes(:db_streams).find(params[:id])
    @db = @db_folder.db
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
