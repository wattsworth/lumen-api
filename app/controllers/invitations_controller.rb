class InvitationsController < Devise::InvitationsController
    include InvitableMethods
    before_action :authenticate_user!, only: :create
    before_action :resource_from_invitation_token, only: [:edit, :update]

    # no create or edit actions
    def create
      head status: :unprocessable_content
    end

    def edit
      head status: :unprocessable_content
    end

    def update
      user = User.accept_invitation!(accept_invitation_params)
      if user.errors.empty?
        render json: { success: ['User updated.'] }, status: :accepted
      else
        @service = StubService.new
        @service.add_errors(user.errors.full_messages)
        render 'helpers/empty_response', status: :unprocessable_content
      end
    end

    private

    def accept_invitation_params
      params.permit(:first_name, :last_name,
        :email,
        :password, :password_confirmation, :invitation_token)
    end
  end
