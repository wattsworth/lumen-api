# frozen_string_literal: true
class PermissionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_nilm
  before_action :authorize_admin

  # GET /permissions
  # GET /permissions.json
  def index
    # return permissions for nilm specified by nilm_id
    @permissions = @nilm.permissions.includes(:user, :user_group)
  end

  # POST /permissions
  # POST /permissions.json
  def create
    # create permission for nilm specified by nilm_id
    @service = CreatePermission.new
    @service.run(@nilm, params[:role], params[:target], params[:target_id])
    @permission = @service.permission
    render status: @service.success? ? :ok : :unprocessable_content
  end

  # DELETE /permissions/1
  # DELETE /permissions/1.json
  def destroy
    # remove permission from nilm specified by nilm_id
    @service = DestroyPermission.new
    @service.run(@nilm, current_user, params[:id])
    render status: @service.success? ? :ok : :unprocessable_content
  end

  # PUT /permissions/create_user.json
  def create_user
    @service = StubService.new
    user = User.new(user_params)
    unless user.save
      @service.errors = user.errors.full_messages
      render 'helpers/empty_response', status: :unprocessable_content
      return
    end
    @service = CreatePermission.new
    @service.run(@nilm, params[:role], 'user', user.id)
    @permission = @service.permission
    @service.add_notice('created user')
    render :create, status: @service.success? ? :ok : :unprocessable_content
  end

  # PUT /permissions/invite_user.json
  def invite_user
    invitation_service = InviteUser.new()
    invitation_service.run(
      current_user,
      params[:email],
      params[:redirect_url])
    unless invitation_service.success?
      @service = invitation_service
      render 'helpers/empty_response', status: :unprocessable_content
      return
    end
    @service = CreatePermission.new
    @service.absorb_status(invitation_service)
    @service.run(@nilm, params[:role], 'user', invitation_service.user.id)
    @permission = @service.permission
    render :create, status: @service.success? ? :ok : :unprocessable_content
  end

  private

  def set_nilm
    @nilm = Nilm.find_by_id(params[:nilm_id])
    head :not_found unless @nilm
  end

  def user_params
    params.permit(:first_name, :last_name, :email,
                  :password, :password_confirmation)
  end

  # authorization based on nilms
  def authorize_admin
    head :unauthorized  unless current_user.admins_nilm?(@nilm)
  end

end
