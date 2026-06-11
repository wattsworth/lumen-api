# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NilmsController, type: :request do
  let(:john) { create(:user, first_name: 'John') }
  let(:nicky) {create(:user, first_name: 'Nicky')}
  let(:steve) { create(:user, first_name: 'Steve') }
  let(:john_nilm) { create(:nilm, name: "John's NILM", admins: [john], owners: [nicky]) }
  let(:lab_nilm) { create(:nilm, name: 'Lab NILM', owners: [john]) }
  let(:pete_nilm) { create(:nilm, name: "Pete's NILM", viewers: [john])}
  let(:hidden_nilm) { create(:nilm, name: "Private NILM", owners: [steve])}

  describe 'GET index' do
    context 'with authenticated user' do
      it 'returns authorized nilms' do
        # force lazy evaluation of let to build NILMs
        john_nilm; pete_nilm; lab_nilm; hidden_nilm
        @auth_headers = john.create_new_auth_token
        get "/nilms.json", headers: @auth_headers
        expect(response.header['Content-Type']).to include('application/json')
        body = JSON.parse(response.body)
        expect(body.length).to eq 3
        body.each do |nilm|
          if(nilm['id']==john_nilm.id)
            expect(nilm["role"]).to eq("admin")
          elsif(nilm['id']==lab_nilm.id)
            expect(nilm["role"]).to eq("owner")
          elsif(nilm['id']==pete_nilm.id)
            expect(nilm["role"]).to eq("viewer")
          else
            fail "unexpected nilm in json response"
          end
        end
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        get "/nilms.json"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT update' do
    context 'with owner permissions' do
      it 'updates parameters' do
        @auth_headers = john.create_new_auth_token
        [john_nilm, lab_nilm].each do |nilm|
          put "/nilms/#{nilm.id}.json",
              params: {id: nilm.id, name: "changed:#{nilm.id}"},
              headers: @auth_headers
              expect(response).to have_http_status(:ok)
          expect(response).to have_notice_message
          expect(nilm.reload.name).to eq("changed:#{nilm.id}")
        end
      end
      it 'returns 422 on invalid nilm parameters' do
        @auth_headers = john.create_new_auth_token
        put "/nilms/#{john_nilm.id}.json",
            params: {id: john_nilm.id, name: ""},
            headers: @auth_headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to have_error_message(/Name/)
        expect(john_nilm.reload.name).to eq("John's NILM")
      end
      it 'returns 422 on invalid db parameters' do
        # max points must be a positive number
        put "/nilms/#{john_nilm.id}.json",
            params: {max_points_per_plot: 'invalid'},
            headers: john.create_new_auth_token
        expect(response.status).to eq(422)
        expect(response).to have_error_message(/not a number/)
      end

      it 'only allows configurable db parameters to be changed' do
        # should ignore url and accept max_points
        size_db = john_nilm.db.size_db
        num_points = john_nilm.db.max_points_per_plot
        put "/nilms/#{john_nilm.id}.json",
            params: {max_points_per_plot: num_points+10, size: 'different'},
            headers:  john.create_new_auth_token
        expect(response.status).to eq(200)
        expect(response).to have_notice_message()
        expect(john_nilm.db.reload.size_db).to eq(size_db)
        expect(john_nilm.db.max_points_per_plot).to eq(num_points+10)
      end
    end
    context 'without admin permissions' do
      it 'returns unauthorized' do
        @auth_headers = john.create_new_auth_token
        num_points = pete_nilm.db.max_points_per_plot
        put "/nilms/#{pete_nilm.id}.json",
            params: {id: pete_nilm.id, name: "test"},
            headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
        expect(pete_nilm.reload.name).to eq("Pete's NILM")
        expect(pete_nilm.db.max_points_per_plot).to eq(num_points)
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        num_points = pete_nilm.db.max_points_per_plot
        put "/nilms/#{pete_nilm.id}.json",
            params: {id: pete_nilm.id, name: "test"}
        expect(response).to have_http_status(:unauthorized)
        expect(pete_nilm.reload.name).to eq("Pete's NILM")
        expect(pete_nilm.db.max_points_per_plot).to eq(num_points)
      end
    end
  end

  describe 'GET show' do
    context 'with any permissions' do

      it 'returns nilm and nested root folder as json' do
        # john has some permission on all 3 nilms
        [pete_nilm, lab_nilm, john_nilm].each do |nilm|
          get "/nilms/#{nilm.id}.json",
              headers: john.create_new_auth_token
          expect(response.status).to eq(200)
          expect(response.header['Content-Type']).to include('application/json')
          body = JSON.parse(response.body)
          expect(body['data']['name']).to eq(nilm.name)
          expect(body['data']['root_folder']['name']).to_not be_empty
        end
      end
      it 'returns data apps as json' do
        test_app = create(:data_app, name: 'test', nilm: john_nilm)
        #john_nilm.data_apps << test_app
        get "/nilms/#{john_nilm.id}.json",
            headers: john.create_new_auth_token
        body = JSON.parse(response.body)
        expect(body['data']['data_apps'][0]['name']).to eq(test_app.name)
        # TODO: figure out a configuration for subdomains
        #expect(body['data']['jouleModules'][0]['url']).to start_with("http://#{test_module.joule_id}.data_app")
      end
      it 'refreshes nilm data when requested' do
        @auth_headers = john.create_new_auth_token
        [john_nilm, lab_nilm].each do |nilm|
          mock_adapter = instance_double(Nilmdb::Adapter)
          mock_service = UpdateNilm.new(mock_adapter)
          expect(mock_service).to receive(:run).and_return StubService.new
          allow(UpdateNilm).to receive(:new)
                           .and_return(mock_service)
          get "/nilms/#{nilm.id}.json?refresh=1",
              headers: @auth_headers
          expect(response).to have_http_status(:ok)
          expect(response.header['Content-Type']).to include('application/json')
        end
      end
      it 'returns error if installation type cannot be determined' do
        expect(NodeAdapterFactory).to receive(:from_nilm).and_return nil
        get "/nilms/#{lab_nilm.id}.json",
            headers: john.create_new_auth_token
        expect(response).to have_http_status(:unprocessable_content)

      end
    end
    context 'with anyone else' do
      it 'returns unauthorized' do
        @auth_headers = steve.create_new_auth_token
        get "/nilms/#{john_nilm.id}.json",
          headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        put "/nilms/#{pete_nilm.id}.json?refresh=1"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST create' do
    context 'for first user' do
      it 'creates a NILM' do
        user_params = {email: "bob@email.com", password: "password",
                       first_name: "Bob", last_name: "Test"}
        nilm_params = {name: "Test Node", api_key: "api_key", port: 8088,
                       scheme: "http", base_uri: "/joule"}
        post "/nilms.json",
          params: user_params.merge(nilm_params)
        # since there is no NILM at this address the response is a 422 error
        expect(response.body).to include("cannot contact node at")
        expect(response).to have_http_status(:unprocessable_content)
        # make sure the NILM was built
        nilm = Nilm.find_by_name('Test Node')
        expect(nilm).to_not be nil
        # user should be an admin
        owner = User.find_by_email("bob@email.com")
        expect(owner.admins_nilm?(nilm)).to be true
      end

      it 'returns errors on invalid request' do
        # all user parameters must be present
        user_params = {email: "bob@email.com", password: "password",
                       first_name: "Bob"}
        nilm_params = {name: "Test Node", api_key: "api_key", port: 8088,
                       scheme: "http", base_uri: "/joule"}
        post "/nilms.json",
             params: user_params.merge(nilm_params)
        expect(response).to have_http_status(:unprocessable_content)
        # has an error message
        expect(response.body).to match("last_name")
        # make sure the NILM was not built
        expect(Nilm.count).to eq 0
        expect(User.count).to eq 0
      end
    end
    context 'for existing users' do
      it 'creates a NILM' do
        owner = create(:user)
        NilmAuthKey.create(user: owner, key: "valid_key")
        user_params = {auth_key: "valid_key"}
        nilm_params = {name: "Test Node", api_key: "api_key", port: 8088,
                       scheme: "http", base_uri: "/joule"}
        post "/nilms.json",
             params: user_params.merge(nilm_params)
        # since there is no NILM at this address the response is a 422 error
        expect(response.body).to include("cannot contact node at")
        expect(response).to have_http_status(:unprocessable_content)
        # make sure the NILM was built
        nilm = Nilm.find_by_name('Test Node')
        expect(nilm).to_not be nil
        # user should be an admin
        expect(owner.admins_nilm?(nilm)).to be true
        # auth key should be destroyed
        expect(NilmAuthKey.count).to eq 0
      end
      it 'requires auth key' do
        create(:user)
        user_params = {email: "bob@email.com", password: "password",
                       first_name: "Bob", last_name: "Test"}
        nilm_params = {name: "Test Node", api_key: "api_key", port: 8088,
                       scheme: "http", base_uri: "/joule"}
        post "/nilms.json",
             params: user_params.merge(nilm_params)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to match("auth_key")
        # make sure the NILM was not built
        expect(Nilm.count).to eq 0
        expect(User.count).to eq 1
        expect(User.find_by_email("bob@email.com")).to be nil
      end
      it 'requires valid auth key' do
        create(:user)
        user_params = {auth_key: "invalid"}
        nilm_params = {name: "Test Node", api_key: "api_key", port: 8088,
                       scheme: "http", base_uri: "/joule"}
        post "/nilms.json",
             params: user_params.merge(nilm_params)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to match("invalid")
        # make sure the NILM was not built
        expect(Nilm.count).to eq 0
        expect(User.count).to eq 1
      end
      it 'returns error on invalid request' do
        owner = create(:user)
        NilmAuthKey.create(user: owner, key: "valid_key")
        user_params = {auth_key: "valid_key"}
        nilm_params = {name: "Missing port param", api_key: "api_key",
                       scheme: "http", base_uri: "/joule"}
        post "/nilms.json",
             params: user_params.merge(nilm_params)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to match("port")
        # make sure the NILM was not built
        expect(Nilm.count).to eq 0
        # user still exists and has an auth key
        expect(User.count).to eq 1
        expect(NilmAuthKey.count).to eq 1
      end
    end
  end

  describe 'DELETE destroy' do
    context 'with nilm admin' do
      it 'removes the nilm' do
        @auth_headers = john.create_new_auth_token
        delete "/nilms/#{john_nilm.id}.json",
          headers: @auth_headers
        expect(response).to have_http_status(:ok)
        expect(response).to have_notice_message
        expect(Nilm.exists?(john_nilm.id)).to be false
      end
    end
    context 'with anybody else' do
      it 'returns unauthorized' do
        @auth_headers = nicky.create_new_auth_token
        delete "/nilms/#{john_nilm.id}.json",
          headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
        expect(Nilm.exists?(john_nilm.id)).to be true
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        delete "/nilms/#{john_nilm.id}.json"
        expect(response).to have_http_status(:unauthorized)
        expect(Nilm.exists?(john_nilm.id)).to be true
      end
    end
  end
end
