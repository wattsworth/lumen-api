require 'cgi'

class ProxyController < ActionController::Base

  #skip_before_action :verify_authenticity_token


  # /app/id.json is DataApp#show
  # /app/id/auth is authenticate
  # /proxy/id is proxied by nginx

  #GET /app/:id/auth
  def authenticate
    # first try to authenticate the user
    if authenticate_interface_user
      response.set_header('X-PROXY-URL', @app.url)
      response.set_header('X-JOULE-KEY', @nilm.key)
      head :ok and return
    end
    app = DataApp.find_by_id(params[:id])
    head :not_found and return if app.nil?
    (head :unauthorized and return) unless request.headers.key?("HTTP_X_ORIGINAL_URI")
    orig_query = URI.parse(request.headers["HTTP_X_ORIGINAL_URI"]).query
    head :unauthorized and return if orig_query.nil?
    params = CGI.parse(orig_query)
    head :unauthorized and return unless params.key?("auth_token")
    token_value = params["auth_token"][0]
    token = InterfaceAuthToken.find_by_value(token_value)
    head :unauthorized and return if token.nil?
    head :unauthorized and return if token.expiration < Time.now
    token.destroy
    # make sure the user is authorized
    head :unauthorized and return unless token.user.views_nilm?(app.nilm)

    session[:user_id]=token.user.id
    # if the app_ids key does not exist initialize it to this app
    session[:app_ids] = session[:app_ids] || [app.id]
    # if it does exist append this app if it is not already in the array
    session[:app_ids] |=[app.id]

    response.set_header('X-PROXY-URL', app.url)
    response.set_header('X-JOULE-KEY', token.data_app.nilm.key)
    head :ok and return
  end


  private

  def authenticate_interface_user
    @current_user = User.find_by_id(session[:user_id])
    return false if @current_user.nil?
    @app = DataApp.find_by_id(params[:id])
    # make sure the app is authorized by the cookie
    return false unless session.include?(:app_ids)
    return false unless session[:app_ids].include?(@app.id)
    @nilm = @app.nilm
    return false if @current_user.nil? || @app.nil?
    return false unless @current_user.views_nilm?(@nilm)
    true
  end

end
