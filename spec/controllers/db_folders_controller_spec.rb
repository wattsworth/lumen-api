# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DbFoldersController, type: :request do
  let(:john) { create(:user, first_name: 'John') }
  let(:steve) { create(:user, first_name: 'Steve') }
  let(:john_nilm) { create(:nilm, name: "John's NILM", admins: [john]) }
  let(:john_folder) do
    create(:db_folder, name: 'John Folder',
                       parent: john_nilm.db.root_folder,
                       db: john_nilm.db)
  end
  let(:lab_nilm) { create(:nilm, name: 'Lab NILM', owners: [john]) }
  let(:lab_folder) do
    create(:db_folder, name: 'Lab Folder',
                       parent: lab_nilm.db.root_folder,
                       db: lab_nilm.db)
  end

  # index action does not exist

  describe 'GET show' do
    context 'with any permissions' do
      it 'returns the db_folder as json' do
        # john has some permission on all 3 nilms
        @auth_headers = john.create_new_auth_token
        [john_folder, lab_folder].each do |folder|
          get "/db_folders/#{folder.id}.json",
              headers: @auth_headers
          expect(response.status).to eq(200)
          expect(response.header['Content-Type']).to include('application/json')
          body = JSON.parse(response.body)
          expect(body['name']).to eq(folder.name)
        end
      end
    end
    context 'without permissions' do
      it 'returns unauthorized' do
        # steve does NOT have permissions on john_nilm
        @auth_headers = steve.create_new_auth_token
        get "/db_folders/#{john_folder.id}.json",
            headers: @auth_headers
        expect(response.status).to eq(401)
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        #  no headers: nobody is signed in, deny all
        get "/db_folders/#{john_folder.id}.json"
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'PUT update' do
    before do
      @mock_adapter = double(Nilmdb::Adapter) # MockDbAdapter.new #instance_double(DbAdapter)
      @node_success = { error: false, msg: 'success' }
      @node_failure = { error: true, msg: 'dberror' }
      allow(NodeAdapterFactory).to receive(:from_nilm).and_return(@mock_adapter)
    end

    context 'with owner permissions' do
      it 'updates nilmdb and local database' do
        @auth_headers = john.create_new_auth_token
        expect(@mock_adapter).to receive(:save_folder)
          .and_return(@node_success)
        put "/db_folders/#{john_folder.id}.json",
            params: { name: 'new name' },
            headers: @auth_headers
        expect(response.status).to eq(200)
        expect(john_folder.reload.name).to eq('new name')
        expect(response).to have_notice_message
      end

      it 'does not update if nilmdb update fails' do
        @auth_headers = john.create_new_auth_token
        expect(@mock_adapter).to receive(:save_folder)
          .and_return(@node_failure)
        name = john_folder.name
        put "/db_folders/#{john_folder.id}.json",
            params: { name: 'new name' },
            headers: @auth_headers
        expect(response.status).to eq(422)
        expect(john_folder.reload.name).to eq(name)
        expect(response).to have_error_message(/dberror/)
      end

      it 'returns 422 on invalid parameters' do
        # name cannot be blank
        expect(@mock_adapter).to_not receive(:save_folder)
        @auth_headers = john.create_new_auth_token
        put "/db_folders/#{john_folder.id}.json",
            params: { name: '' },
            headers: @auth_headers
        expect(response.status).to eq(422)
        expect(response).to have_error_message(/blank/)
      end

      it 'only allows configurable parameters to be changed' do
        # should ignore start_time and accept description
        expect(@mock_adapter).to receive(:save_folder)
          .and_return(@node_success)
        @auth_headers = john.create_new_auth_token
        start_time = john_folder.start_time
        put "/db_folders/#{john_folder.id}.json",
            params: { start_time: start_time + 10, description: 'changed' },
            headers: @auth_headers
        expect(response.status).to eq(200)
        expect(john_folder.reload.start_time).to eq(start_time)
        expect(john_folder.description).to eq('changed')
      end

      it 'fails if an adapter cannot be created' do
        allow(NodeAdapterFactory).to receive(:from_nilm).and_return(nil)
        put "/db_folders/#{john_folder.id}.json",
            params: { name: 'new name' },
            headers: john.create_new_auth_token
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to have_error_message
      end
    end


    context 'without owner permissions' do

      it 'returns unauthorized' do
        @auth_headers = steve.create_new_auth_token
        name = john_folder.name
        put "/db_folders/#{john_folder.id}.json",
            params: { name: 'ignored' },
            headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
        expect(john_folder.reload.name).to eq(name)
      end
    end


    context 'without sign-in' do
      it 'returns unauthorized' do
        name = john_folder.name
        put "/db_folders/#{john_folder.id}.json",
            params: { name: 'ignored' }
        expect(response).to have_http_status(:unauthorized)
        expect(john_folder.name).to eq(name)
      end
    end
  end
end
