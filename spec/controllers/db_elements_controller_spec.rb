# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DbElementsController, type: :request do
  let(:user1) { create(:user, first_name: 'John') }
  let(:user2) { create(:user, first_name: 'Sam') }
  describe 'GET #data' do
    # retrieve data for elements listed by array of ids
    context 'with authenticated user' do
      before do
        nilm = create(:nilm, admins: [user1])
        stream = create(:db_stream, elements_count: 0,
                                    db: nilm.db,
                                    db_folder: nilm.db.root_folder)
        @elem1 = create(:db_element, db_stream: stream)
        @elem2 = create(:db_element, db_stream: stream)
      end
      it "returns elements with data" do
        @service_data = [{ id: @elem1.id, data: 'mock1' },
                         { id: @elem2.id, data: 'mock2' }]
        @mock_service = instance_double(LoadElementData,
                                        run: StubService.new,
                                        start_time: 0,
                                        end_time: 1,
                                        success?: true, notices: [], warnings: [], errors: [],
                                        data: @service_data)
        allow(LoadElementData).to receive(:new).and_return(@mock_service)

        @auth_headers = user1.create_new_auth_token
        get '/db_elements/data.json',
            params: { elements: [@elem1.id, @elem2.id].to_json,
                      start_time: 0, end_time: 100 },
            headers: @auth_headers
        expect(response).to have_http_status(:ok)
        # check to make sure JSON renders the elements
        body = JSON.parse(response.body)
        expect(body['data'].count).to eq(2)
      end

      it 'computes padding if specified' do
        @service_data = [{ id: @elem1.id, data: 'mock1' },
                         { id: @elem2.id, data: 'mock2' }]
        @mock_service = instance_double(LoadElementData,
                                        run: StubService.new,
                                        success?: true, notices: [], warnings: [], errors: [],
                                        data: @service_data)
        allow(LoadElementData).to receive(:new).and_return(@mock_service)
        expect(@mock_service).to receive(:run).with([@elem1,@elem2],90,210,nil)
        @auth_headers = user1.create_new_auth_token
        get '/db_elements/data.json',
            params: { elements: [@elem1.id, @elem2.id].to_json,
                      start_time: 100, end_time: 200, padding: 0.1 },
            headers: @auth_headers
        expect(response).to have_http_status(:ok)
        # check to make sure JSON renders the elements
        body = JSON.parse(response.body)
        expect(body['data'].count).to eq(2)
        # reported time bounds should *NOT* include padding
        body['data'].map do |data|
          expect(data['start_time']).to eq 100
          expect(data['end_time']).to eq 200
        end
      end
      it 'returns error if time bounds are invalid' do
        @auth_headers = user1.create_new_auth_token
        get '/db_elements/data.json',
            params: { elements: [@elem1.id, @elem2.id].to_json,
                      start_time: 100, end_time: 0 },
            headers: @auth_headers
        expect(response).to have_http_status(:unprocessable_content)
      end
      it 'only allows access to permitted elements' do
        nilm2 = create(:nilm, admins: [user2])
        stream2 = create(:db_stream, elements_count: 0,
                                     db: nilm2.db,
                                     db_folder: nilm2.db.root_folder)
        @elem3 = create(:db_element, db_stream: stream2)

        @auth_headers = user1.create_new_auth_token
        get '/db_elements/data.json',
            params: { elements: [@elem1.id, @elem3.id].to_json,
                      start_time: 100, end_time: 0 },
            headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
      end
      it 'auto calculates time bounds if not specified' do
        @service_data = [{ id: @elem1.id, data: 'mock1' },
                         { id: @elem2.id, data: 'mock2' }]
        @mock_service = instance_double(LoadElementData,
                                        run: StubService.new,
                                        start_time: 985,
                                        end_time: 10001,
                                        success?: true, notices: [], warnings: [], errors: [],
                                        data: @service_data)
        allow(LoadElementData).to receive(:new).and_return(@mock_service)

        @auth_headers = user1.create_new_auth_token
        get '/db_elements/data.json',
            params: { elements: [@elem1.id, @elem2.id].to_json },
            headers: @auth_headers
        expect(response).to have_http_status(:ok)
        # check to make sure JSON renders the elements
        body = JSON.parse(response.body)
        expect(body['data'].count).to eq(2)
        expect(body['data'][0]['start_time']).to eq(985)
        expect(body['data'][0]['end_time']).to eq(10001)
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        get '/db_elements/data.json'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
