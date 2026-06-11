require 'rails_helper'

RSpec.describe DataViewsController, type: :request do

  let(:viewer) { create(:user)}
  let(:nilm) { create(:nilm, name: 'my_nilm', viewers: [viewer]) }
  let(:db) { create(:db, nilm: nilm)}
  let(:viewed_streams) { [
    create(:db_stream, db: db, db_folder: db.root_folder),
    create(:db_stream, db: db, db_folder: db.root_folder)]}

  describe 'GET index' do
    context 'with authenticated user' do
      it 'returns all loadable data views' do
        other_nilm = create(:nilm, name: 'other_nilm')
        other_db = create(:db, nilm: other_nilm)
        other_stream = create(:db_stream, db: other_db, db_folder: other_db.root_folder)
        other_user = create(:user)
        service = CreateDataView.new
        service.run(
          {name: 'allowed', visibility: 'public'}, [viewed_streams.first.id], other_user)
        service.run(
          {name: 'prohibited', visibility: 'public'}, [other_stream.id], other_user)
        service.run(
          {name: 'private', visibility: 'private'}, [viewed_streams.first.id], other_user)
        service.run(
          {name: 'my_public', visibility: 'public'}, viewed_streams.map{|x| x.id}, viewer)
        service.run(
          {name: 'my_private', visibility: 'private'}, viewed_streams.map{|x| x.id}, viewer)

        #viewer should receive 'allowed' and 'created'
        @auth_headers = viewer.create_new_auth_token
        get "/data_views.json", headers: @auth_headers
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        names = body.map {|view| view['name']}
        expect(names).to contain_exactly('allowed','my_public','my_private')
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        get "/data_views.json"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET home' do
    context 'with authenticated user' do
      it 'returns user home data view' do
        user1 = create(:user)
        dv1 = create(:data_view, owner: user1)
        user1.update(home_data_view: dv1)
        user2 = create(:user)
        dv2 = create(:data_view, owner: user2)
        user2.update(home_data_view: dv2)
        #user1 gets his view
        @auth_headers = user1.create_new_auth_token
        get "/data_views/home.json", headers: @auth_headers
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["id"]).to eq dv1.id
        #user2 gets his view
        @auth_headers = user2.create_new_auth_token
        get "/data_views/home.json", headers: @auth_headers
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["id"]).to eq dv2.id
      end
      it 'returns 404:not_found if data view is unset' do
        user = create(:user)
        @auth_headers = user.create_new_auth_token
        get "/data_views/home.json", headers: @auth_headers
        expect(response).to have_http_status(:not_found)
        expect(response.body).to be_empty
      end
    end
  end
  describe 'POST create' do
    context 'with authenticated user' do
      it 'creates a dataview' do
        @auth_headers = viewer.create_new_auth_token
        post "/data_views.json",
          params: {
            name: 'test', description: '', image: '', redux_json: '',
             visibility: 'public', stream_ids: viewed_streams.map {|x| x.id}
          }, headers: @auth_headers
        expect(response).to have_http_status(:ok)
        expect(response).to have_notice_message
        body = JSON.parse(response.body)
        #viewer should own this new dataview
        expect(body['data']['owner']).to be(true)
      end
      it 'creates home data views' do
        @auth_headers = viewer.create_new_auth_token
        post "/data_views.json",
          params: {
            home: true,
            name: 'new home view', description: '', image: '', redux_json: '',
            visibility: 'public', stream_ids: viewed_streams.map {|x| x.id}
          }, headers: @auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(response).to have_notice_message
        body = JSON.parse(response.body)
        #viewer should own this new dataview
        expect(body['data']['owner']).to be(true)
        expect(viewer.reload.home_data_view.name).to eq('new home view')
      end
      it 'returns error with bad parameters' do
        @auth_headers = viewer.create_new_auth_token
        post "/data_views.json",
          params: {
            description: 'missing name', image: '', redux_json: '',
            visibility: 'public', stream_ids: viewed_streams.map {|x| x.id}
          }, headers: @auth_headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to have_error_message
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        post "/data_views.json"
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'PUT update' do
    context 'with view owner' do
      it 'can set home view' do
        view = create(:data_view, name: 'old name', owner: viewer)
        @auth_headers = viewer.create_new_auth_token
        put "/data_views/#{view.id}.json",
          params: {
            name: 'new name', home: true
          }, headers: @auth_headers, as: :json
        expect(viewer.reload.home_data_view).to eq(view)
        expect(view.reload.name).to eq 'new name'
        expect(response).to have_http_status(:ok)
        expect(response).to have_notice_message
      end

      it 'can remove home view' do
        view = create(:data_view, name: 'old name', owner: viewer)
        viewer.update(home_data_view: view)
        @auth_headers = viewer.create_new_auth_token
        put "/data_views/#{view.id}.json",
          params: {
            name: 'new name', home: false
          }, headers: @auth_headers, as: :json
        expect(viewer.reload.home_data_view).to be nil
        expect(view.reload.name).to eq 'new name'
        expect(response).to have_http_status(:ok)
        expect(response).to have_notice_message
      end
      it 'cannot change redux_json or image' do
        view = create(:data_view, name: 'old name',
          redux_json: 'valid_json', image: 'valid_image', owner: viewer)
        viewer.update(home_data_view: view)
        @auth_headers = viewer.create_new_auth_token
        put "/data_views/#{view.id}.json",
          params: {
            name: 'new name', redux_json: 'banned', image: 'banned'
          }, headers: @auth_headers, as: :json
        expect(viewer.reload.home_data_view).to be nil
        expect(view.reload.name).to eq 'new name'
        expect(view.redux_json).to eq 'valid_json'
        expect(view.image).to eq 'valid_image'
        expect(response).to have_http_status(:ok)
        expect(response).to have_notice_message
      end
      it 'returns error with invalid parameters' do
        view = create(:data_view, name: 'old name', owner: viewer)
        @auth_headers = viewer.create_new_auth_token
        put "/data_views/#{view.id}.json",
            params: {
                name: '', home: false
            }, headers: @auth_headers, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(DataView.find(view.id).name).to eq "old name"
      end
    end
    context 'with anybody else' do
      it 'returns unauthorized' do
        other_user = create(:user)
        view = create(:data_view, name: 'old name', owner: viewer)
        @auth_headers = other_user.create_new_auth_token
        put "/data_views/#{view.id}.json",
          params: {
            name: 'new name'
          }, headers: @auth_headers, as: :json
        expect(view.reload.name).to eq 'old name'
        expect(response).to have_http_status(:unauthorized)
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        view = create(:data_view, name: 'old name', owner: viewer)
        put "/data_views/#{view.id}.json",
          params: {
            name: 'new name'
          }, as: :json
        expect(view.reload.name).to eq 'old name'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE destroy' do
    before do
      service = CreateDataView.new
      service.run(
        {name: 'created', visibility: 'public'}, viewed_streams.map{|x| x.id}, viewer)
      @my_view = service.data_view
    end
    context 'with view owner' do
      it 'removes the data view' do
        @auth_headers = viewer.create_new_auth_token
        delete "/data_views/#{@my_view.id}.json",
               headers: @auth_headers
        expect(response).to have_http_status(:ok)
        expect(response).to have_notice_message
        expect(DataView.exists?(@my_view.id)).to be false
        # make sure the associated permissions are destroyed
        expect(DataViewsNilm.count).to eq(0)
      end
    end
    context 'with anybody else' do
      it 'returns unauthorized' do
        other_user = create(:user)
        @auth_headers = other_user.create_new_auth_token
        delete "/data_views/#{@my_view.id}.json",
               headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
        expect(DataView.exists?(@my_view.id)).to be true
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        delete "/data_views/#{@my_view.id}.json"
        expect(response).to have_http_status(:unauthorized)
        expect(DataView.exists?(@my_view.id)).to be true
      end
    end
  end
end
