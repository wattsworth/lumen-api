# frozen_string_literal: true

require 'rails_helper'
require 'json'

# Test Database Schema:
# │
# ├── folder_1
# │   ├── stream_1_1: float32_3
# │   └── stream_1_2: uint8_3
# ├── folder_2
# │   └── stream_2_1: int16_2
# │   └── transients (event stream)
# │   └── loads (event stream)
# ├── folder_3
# │   ├── folder_3_1
# │   │   └── stream_3_1_1: int32_3
# │   └── stream_3_1: uint16_3
# └── folder_4
#     └── folder_4_1

def load_schema(schema_name)
  raw = File.read(File.dirname(__FILE__)+"/test_schema/#{schema_name}.json")
  JSON.parse(raw).deep_symbolize_keys
end
describe Joule::UpdateDb do
  before do
    nilm = create(:nilm)
    @db = nilm.db
  end

  let(:dbinfo) { {} }
  describe '*run*' do
    describe 'given the original schema' do
      it 'builds the database' do
        service = Joule::UpdateDb.new(@db)
        service.run(load_schema('0_original_schema'))
        expect(@db.root_folder.subfolders.count).to eq 4
        # go through Folder 1 carefully
        folder_1 = @db.root_folder.subfolders.where(name: 'folder_1').first
        expect(folder_1.subfolders.count).to eq 0
        expect(folder_1.db_streams.count).to eq 2
        expect(folder_1.path).to eq '/folder_1'
        stream_1_1 = folder_1.db_streams.where(name: 'stream_1_1').first
        expect(stream_1_1.data_type).to eq 'float32_3'
        expect(stream_1_1.path).to eq '/folder_1/stream_1_1'
        expect(stream_1_1.db_elements.count).to eq 3
        x = stream_1_1.db_elements.where(name: 'x').first
        expect(x.display_type).to eq 'continuous'
        expect(x.column).to eq 0
        expect(x.default_max).to eq 100
        y = stream_1_1.db_elements.where(name: 'y').first
        expect(y.display_type).to eq 'event'
        expect(y.column).to eq 1
        expect(y.default_min).to eq -6
        z = stream_1_1.db_elements.where(name: 'z').first
        expect(z.display_type).to eq 'discrete'
        expect(z.column).to eq 2
        expect(z.units).to eq "watts"
        # check for event streams in Folder 2
        folder_2 = @db.root_folder.subfolders.where(name: 'folder_2').first
        expect(folder_2.event_streams.count).to eq 2
        load_events = folder_2.event_streams.where(name: 'loads').first
        expect(load_events.path).to eq '/folder_2/loads'
        # aggregate checks
        expect(DbElement.count).to eq 14
        expect(DbStream.count).to eq 5
        expect(DbFolder.count).to eq 7
        expect(EventStream.count).to eq 2



        #################################
        ### Now update the schema (1) ###
        #################################
        puts "##### update schema #######"
        folder_4_last_update = DbFolder.where(name:"folder_4").first.updated_at
        stream_3_1_last_update = DbStream.where(name:"stream_3_1").first.updated_at
        service.run(load_schema('1_updated_schema'))
        # aggregate checks
        expect(@db.root_folder.subfolders.count).to eq 4
        expect(DbElement.count).to eq 14
        expect(DbStream.count).to eq 5
        expect(DbFolder.count).to eq 7
        expect(EventStream.count).to eq 2
        # stream_3_1_1 has element with new units
        folder_3 = @db.root_folder.subfolders.where(name: 'folder_3').first
        folder_3_1 = folder_3.subfolders.where(name: 'folder_3_1').first
        stream_3_1_1 = folder_3_1.db_streams.where(name: 'stream_3_1_1').first
        expect(stream_3_1_1.db_elements.where(name:"0").first.units).to eq "updated_units"
        # stream_1_2 has updated description
        expect(DbStream.where(name:"stream_1_2").first.description).to eq "updated_description"
        # transients event stream has updated event_fields
        expect(EventStream.where(name:"transients").count).to eq 1
        expect(EventStream.where(name:"transients").first.event_fields).to eq({"updated"=>"string"})
        # folder 4 should not be updated
        folder_4 = @db.root_folder.subfolders.where(name: 'folder_4').first
        expect(folder_4.updated_at).to eq folder_4_last_update
        # stream_3_1 should not be updated
        expect( DbStream.where(name:"stream_3_1").first.updated_at).to eq stream_3_1_last_update

        #################################
        ### Now update the schema (2) ###
        #################################
        puts "##### move schema #######"
        folder_3_orig_id = DbFolder.where(name:"folder_3").first.id
        stream_1_2_orig_id = DbStream.find_by_name("stream_1_2").id
        service.run(load_schema('2_moved_schema'))
        # aggregate checks
        expect(@db.root_folder.subfolders.count).to eq 3
        expect(DbFolder.count).to eq 7
        expect(EventStream.count).to eq 2
        expect(DbElement.count).to eq 14
        expect(DbStream.count).to eq 5

        # folder 3 has been moved under folder 4
        folder_3 = DbFolder.where(name:"folder_3").first
        folder_4 = DbFolder.where(name:"folder_4").first
        expect(folder_3.parent.id).to eq folder_4.id
        expect(folder_3.id).to eq folder_3_orig_id

        # stream_1_2 has been moved to folder_4_1
        stream_1_2 = DbStream.find_by_name("stream_1_2")
        expect(stream_1_2.db_folder.name).to eq "folder_4_1"
        expect(stream_1_2.id).to eq stream_1_2_orig_id

        #################################
        ### Now update the schema (3) ###
        #################################
        puts "##### delete schema #######"
        service.run(load_schema('3_deleted_schema'))
        # aggregate checks
        expect(@db.root_folder.subfolders.count).to eq 2
        expect(DbFolder.count).to eq 6
        expect(EventStream.count).to eq 1
        expect(DbElement.count).to eq 9
        expect(DbStream.count).to eq 3
        # make sure folder_2 and stream_2_1 are gone
        expect(DbStream.find_by_name("stream_2_1")).to be nil
        expect(DbFolder.find_by_name("folder_2")).to be nil
        # make sure stream_3_1 is gone
        expect(DbStream.find_by_name("stream_3_1")).to be nil
        # loads event stream should be under folder_4_1
        expect(EventStream.find_by_name("loads").db_folder.name).to eq "folder_4_1"

        #################################
        ### Now update the schema (4) ###
        #################################
        puts "##### add schema #######"
        service.run(load_schema('4_added_schema'))
        # aggregate checks
        expect(@db.root_folder.subfolders.count).to eq 3
        expect(DbFolder.count).to eq 7
        expect(EventStream.count).to eq 2
        expect(DbElement.count).to eq 10
        expect(DbStream.count).to eq 4
        # make sure new data and event stream are both present
        expect(DbStream.find_by_name("new_data_stream")).not_to be_nil
        expect(EventStream.find_by_name("new_event_stream")).not_to be_nil
        new_folder = DbFolder.find_by_name("new")
        expect(new_folder.db_streams.count).to eq 1
        expect(new_folder.event_streams.count).to eq 1
        new_event_stream_id = EventStream.find_by_name("new_event_stream").id
        folder_4_id = DbFolder.find_by_name("folder_4").id
        folder_3_id = DbFolder.find_by_name("folder_3").id
        #################################
        ### Now update the schema (5) ###
        #################################
        puts "##### remove and add new with same name #######"
        service.run(load_schema('5_modified_schema'))
        # aggregate checks
        expect(@db.root_folder.subfolders.count).to eq 3
        expect(DbFolder.count).to eq 8
        expect(EventStream.count).to eq 4
        expect(DbElement.count).to eq 13
        expect(DbStream.count).to eq 5
        # expect things that moved to have the same id...
        expect(DbFolder.find_by_name("folder_4").id).to eq folder_4_id
        expect(DbFolder.find_by_name("folder_3").id).to eq folder_3_id
        # ...but be in a new location...
        expect(DbFolder.find(folder_4_id).parent.name).to eq "folder_1"
        expect(DbFolder.find(folder_3_id).parent.name).to eq "folder_1"
        expect(EventStream.find(new_event_stream_id).db_folder.name).to eq "folder_4"
        # ...and have the same attributes as before
        expect(EventStream.find(new_event_stream_id).name).to eq "new_event_stream"
        # expect new items to be added
        expect(DbFolder.where(name:"new").first.event_streams.first.name).to eq "new_event_stream"
        expect(DbFolder.where(name:"folder_1").first.db_streams.first.name).to eq "stream_1_1"
        expect(@db.root_folder.subfolders.where(name: "folder_4").first).not_to be_nil
      end
    end
  end
end