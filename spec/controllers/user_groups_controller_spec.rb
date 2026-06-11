# frozen_string_literal: true
require 'rails_helper'

RSpec.describe UserGroupsController, type: :request do
  let(:owner) { create(:user) }
  let(:member1) { create(:user) }
  let(:member2) { create(:user) }
  let(:other_user) { create(:user) }
  let(:group) do
    create(:user_group,
           owner: owner,
           members: [member1, member2])
  end

  describe 'GET index' do
    let(:grp1) { create(:user_group, name: 'Group1') }
    let(:grp2) { create(:user_group, name: 'Group2') }
    let(:donnals) do
      create(:user_group, name: 'Donnals',
                          owner: john, members: [nicky])
    end
    let(:john) { create(:user, first_name: 'Jonh') }
    let(:nicky) { create(:user, first_name: 'Nicky') }
    let(:steve) { create(:user, first_name: 'Steve') }

    before do
      # force lazy evaluation of let to build groups
      grp1; grp2; donnals
    end

    context 'with john' do
      it 'returns 1 owner, 0 members, 2 others' do
        @auth_headers = john.create_new_auth_token
        get '/user_groups.json', headers: @auth_headers
        expect(response.header['Content-Type']).to include('application/json')
        body = JSON.parse(response.body)
        expect(body['owner'].length).to eq(1)
        expect(body['owner'][0]['members'].length).to eq(1)
        expect(body['member'].length).to eq(0)
        expect(body['other'].length).to eq(2)
      end
    end
    context 'with nicky' do
      it 'returns 0 owners, 1 member, 2 others' do
        @auth_headers = nicky.create_new_auth_token
        get '/user_groups.json', headers: @auth_headers
        expect(response.header['Content-Type']).to include('application/json')
        body = JSON.parse(response.body)
        expect(body['owner'].length).to eq(0)
        expect(body['member'].length).to eq(1)
        expect(body['other'].length).to eq(2)
      end
    end
    context 'with steve' do
      it 'returns 0 owners, 0 members, 3 others' do
        @auth_headers = steve.create_new_auth_token
        get '/user_groups.json', headers: @auth_headers
        expect(response.header['Content-Type']).to include('application/json')
        body = JSON.parse(response.body)
        expect(body['owner'].length).to eq(0)
        expect(body['member'].length).to eq(0)
        expect(body['other'].length).to eq(3)
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        get '/user_groups.json'
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'PUT add_member' do
    context 'with owner' do
      it 'adds a member' do
        @auth_headers = owner.create_new_auth_token
        put "/user_groups/#{group.id}/add_member.json",
            params: { user_id: other_user.id },
            headers: @auth_headers
        expect(response.status).to eq(200)
        expect(group.reload.users.include?(other_user)).to be true
        expect(response).to have_notice_message
        # check to make sure JSON renders the members
        body = JSON.parse(response.body)
        expect(body['data']['members'].count).to eq group.users.count
      end
      it 'returns error on invalid request' do
        @auth_headers = owner.create_new_auth_token
        # member1 is already a member
        put "/user_groups/#{group.id}/add_member.json",
            params: { user_id: member1.id },
            headers: @auth_headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to have_error_message
      end
    end
    context 'with anyone else' do
      it 'returns unauthorized' do
        @auth_headers = member1.create_new_auth_token
        put "/user_groups/#{group.id}/add_member.json",
            params: { user_id: other_user.id },
            headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        put "/user_groups/#{group.id}/add_member.json",
            params: { user_id: other_user.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT create_member' do
    context 'with owner' do
      it 'creates a user and adds him to the group' do
        members = group.users.length
        @auth_headers = owner.create_new_auth_token
        put "/user_groups/#{group.id}/create_member.json",
            params: { first_name: 'bill', last_name: 'will',
                      email: 'valid@url.com', password: 'poorchoice',
                      password_confirmation: 'poorchoice' },
            headers: @auth_headers
        expect(response).to have_http_status(:ok)
        expect(User.find_by_email('valid@url.com')).to_not be nil
        expect(response).to have_notice_message
        # make sure response contains the new user
        expect(response.header['Content-Type']).to include('application/json')
        body = JSON.parse(response.body)
        expect(body['data']['members'].length).to eq(members + 1)
      end
      it 'returns error message if user has errors' do
        @auth_headers = owner.create_new_auth_token
        put "/user_groups/#{group.id}/create_member.json",
            params: { first_name: 'bill', last_name: 'will',
                      email: 'valid@url.com', password: 'poorchoice',
                      password_confirmation: 'nomatch' },
            headers: @auth_headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(User.find_by_email('valid@url.com')).to be nil
        expect(response).to have_error_message
      end
    end
    context 'with anyone else' do
      it 'returns unauthorized' do
        @auth_headers = member1.create_new_auth_token
        put "/user_groups/#{group.id}/create_member.json",
            params: { first_name: 'bill', last_name: 'will',
                      email: 'valid@url.com', password: 'poorchoice',
                      password_confirmation: 'poorchoice' },
            headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
        expect(User.find_by_email('valid@url.com')).to be nil
      end
    end
    context 'without sigin' do
      it 'returns unauthorized' do
        put "/user_groups/#{group.id}/create_member.json",
            params: { first_name: 'bill', last_name: 'will',
                      email: 'valid@url.com', password: 'poorchoice',
                      password_confirmation: 'poorchoice' }
        expect(response).to have_http_status(:unauthorized)
        expect(User.find_by_email('valid@url.com')).to be nil
      end
    end
  end

  describe 'PUT invite_member' do
    context 'with owner' do
      before do
        @auth_headers = owner.create_new_auth_token
      end
      it 'invites a user and adds him to the group' do
        put "/user_groups/#{group.id}/invite_member.json",
            params: { email: 'test@test.com', redirect_url: 'localhost' },
            headers: @auth_headers
        expect(response.status).to eq(200)
        # new user is created
        @invitee = User.find_by_email('test@test.com')
        # invited by current user
        expect(@invitee.invited_by).to eq owner
        # new user is a group member
        expect(group.reload.users.include?(@invitee)).to be true
        # new user is not included in group list
        members = JSON.parse(response.body)['data']['members']
        expect(members.select { |u| u == @invitee }).to be_empty
      end
      it 'adds existing users to the group' do
        user = create(:user, email: 'member@test.com')
        url = "/user_groups/#{group.id}/invite_member.json"
        user_count = User.count
        put url,
            params: { email: 'member@test.com', redirect_url: 'localhost' },
            headers: @auth_headers
        expect(response.status).to eq(200)
        # no new user is created
        expect(User.count).to eq user_count
        # user is a group member
        expect(group.reload.users.include?(user)).to be true
        # user is included in group list
        members = JSON.parse(response.body)['data']['members']
        expect(members.select { |u| u['id'] == user.id }).to_not be_empty
      end
      it 'returns error if service call fails' do
        failed_service = InviteUser.new
        failed_service.add_error("test message")
        expect(InviteUser).to receive(:new).and_return failed_service
        put "/user_groups/#{group.id}/invite_member.json",
            params: { email: 'test@test.com', redirect_url: 'localhost' },
            headers: @auth_headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to have_error_message
      end
    end
    context 'with anyone else' do
      it 'returns unauthorized' do
        @auth_headers = member1.create_new_auth_token
        put "/user_groups/#{group.id}/invite_member.json",
            params: { email: 'member@test.com', redirect_url: 'localhost' },
            headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
    context 'without sigin' do
      it 'returns unauthorized' do
        put "/user_groups/#{group.id}/invite_member.json",
            params: { email: 'member@test.com', redirect_url: 'localhost' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT remove_member' do
    context 'with owner' do
      it 'removes a member' do
        @auth_headers = owner.create_new_auth_token
        put "/user_groups/#{group.id}/remove_member.json",
            params: { user_id: member1.id },
            headers: @auth_headers
        expect(response.status).to eq(200)
        expect(group.reload.users.include?(member1)).to be false
        expect(response).to have_notice_message
        # check to make sure JSON renders the members
        body = JSON.parse(response.body)
        expect(body['data']['members'].count).to eq group.users.count
      end
      it 'returns error on invalid request' do
        @auth_headers = owner.create_new_auth_token
        # other_user is not a member
        put "/user_groups/#{group.id}/remove_member.json",
            params: { user_id: other_user.id },
            headers: @auth_headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to have_error_message
      end
    end
    context 'with anyone else' do
      it 'returns unauthorized' do
        @auth_headers = member1.create_new_auth_token
        put "/user_groups/#{group.id}/remove_member.json",
            params: { user_id: member2.id },
            headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        put "/user_groups/#{group.id}/remove_member.json",
            params: { user_id: other_user.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST create' do
    context 'with authenticated user' do
      it 'creates a group' do
        @auth_headers = other_user.create_new_auth_token
        post '/user_groups.json',
             params: { name: 'test_group', description: 'some text' },
             headers: @auth_headers
        expect(response).to have_http_status(:ok)
        expect(response).to have_notice_message
        expect(UserGroup.find_by_name('test_group').owner).to eq other_user
        # check to make sure JSON renders the members
        body = JSON.parse(response.body)
        # no members yet
        expect(body['data']['members'].count).to eq 0
      end
      it 'returns error if unsuccesful' do
        @auth_headers = other_user.create_new_auth_token
        create(:user_group, name: 'CanOnlyBeOne')
        post '/user_groups.json',
             params: { name: 'CanOnlyBeOne', description: 'some text' },
             headers: @auth_headers
        # can't have duplicate name
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to have_error_message(/Name/)
        expect(UserGroup.where(name: 'CanOnlyBeOne').count).to eq 1
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        post '/user_groups.json',
             params: { name: 'test', description: 'something' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE destroy' do
    context 'with group owner' do
      it 'removes the group and associated data' do
        @auth_headers = owner.create_new_auth_token
        nilm = create(:nilm, admins: [group])
        pCount = Permission.count
        delete "/user_groups/#{group.id}.json",
               headers: @auth_headers
        expect(response).to have_http_status(:ok)
        expect(response).to have_notice_message
        expect(UserGroup.exists?(group.id)).to be false
        # make sure the associated permissions are destroyed
        expect(Permission.count).to eq(pCount - 1)
      end
    end
    context 'with anybody else' do
      it 'returns unauthorized' do
        @auth_headers = member1.create_new_auth_token
        delete "/user_groups/#{group.id}.json",
               headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
        expect(UserGroup.exists?(group.id)).to be true
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        delete "/user_groups/#{group.id}.json"
        expect(response).to have_http_status(:unauthorized)
        expect(UserGroup.exists?(group.id)).to be true
      end
    end
  end

  describe 'PUT update' do
    context 'with owner' do
      it 'updates the group' do
        @auth_headers = owner.create_new_auth_token
        put "/user_groups/#{group.id}.json",
            params: { name: 'new', description: 'changed' },
            headers: @auth_headers
        expect(response).to have_http_status(:ok)
        expect(response).to have_notice_message
        expect(group.reload.name).to eq('new')
        expect(group.description).to eq('changed')
        # check to make sure JSON renders the members
        body = JSON.parse(response.body)
        expect(body['data']['members'].count).to eq group.users.count
      end
      it 'returns error if unsuccesful' do
        @auth_headers = owner.create_new_auth_token
        orig_name = group.name
        # name cannot be blank
        put "/user_groups/#{group.id}.json",
            params: { name: '', description: 'changed' },
            headers: @auth_headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to have_error_message
        expect(group.reload.name).to eq(orig_name)
      end
    end
    context 'with anybody else' do
      it 'returns unauthorized' do
        @auth_headers = member1.create_new_auth_token
        orig_name = group.name
        put "/user_groups/#{group.id}.json",
            params: { name: 'new', description: 'changed' },
            headers: @auth_headers
        expect(response).to have_http_status(:unauthorized)
        expect(group.reload.name).to eq orig_name
      end
    end
    context 'without sign-in' do
      it 'returns unauthorized' do
        orig_name = group.name
        put "/user_groups/#{group.id}.json",
            params: { name: 'new', description: 'changed' }
        expect(response).to have_http_status(:unauthorized)
        expect(group.reload.name).to eq orig_name
      end
    end
  end
end
