# frozen_string_literal: true
require 'rails_helper'


RSpec.describe 'ReadEvents' do
  let(:nilm) {create(:nilm, name: 'test')}
  let(:db) { create(:db, nilm: nilm, max_points_per_plot: 100) }

  describe 'when there are multiple event streams' do
    before do
      db  = create(:db, nilm: nilm, url: 'http://test/nilmdb')
      @event_stream1 = create(:event_stream, db_folder: db.root_folder, db: db)
      @event_stream1_data = {id: @event_stream1.id, valid: true, events: ["event1", "event2"]}
      @event_stream2 = create(:event_stream, db_folder: db.root_folder, db: db)
      @event_stream2_data = {id: @event_stream2.id, valid: true, events: ["event3", "event4"]}

      @mock_adapter = MockAdapter.new(nil,
          [{event_stream: @event_stream1, data: @event_stream1_data},
                  {event_stream: @event_stream2, data: @event_stream2_data}])
      allow(NodeAdapterFactory).to receive(:from_nilm).and_return(@mock_adapter)

    end
    it 'makes one request per stream' do
      service = ReadEvents.new
      service.run([{
                       stream: @event_stream1, filter: []},
                       stream: @event_stream2, filter:[]],
                  0,100)
      expect(service.success?).to be true
      expect(service.data).to eq [@event_stream1_data, @event_stream2_data]
      expect(@mock_adapter.event_run_count).to eq 2
    end
  end

  describe 'when a nilm does not respond' do
    before do
      db  = create(:db, nilm: nilm, url: 'http://test/nilmdb')
      @event_stream1 = create(:event_stream, db_folder: db.root_folder, db: db)
      @event_stream1_data = {id: @event_stream1.id, valid: true, events: ["event1", "event2"]}
      @event_stream2 = create(:event_stream, db_folder: db.root_folder, db: db)

      @mock_adapter = MockAdapter.new(nil,
                                      [{event_stream: @event_stream1, data: @event_stream1_data},
                                       {event_stream: @event_stream2, data: nil}])
      allow(NodeAdapterFactory).to receive(:from_nilm).and_return(@mock_adapter)

    end
    it 'fills in the data that is available' do
      service = ReadEvents.new
      service.run([{stream: @event_stream1, filter: []},
                   stream: @event_stream2, filter:[]],0,100)
      expect(service.warnings.length).to eq 1
      expect(service.data).to eq [
                                     @event_stream1_data,
                                     {id: @event_stream2.id, valid: false, tag: nil, events: nil, count: 0}
                                 ]
      expect(@mock_adapter.event_run_count).to eq 2
    end
  end

  #NOTE: This is really quite a large integration test, it
  #builds the full test nilm and then retrieves events from it.
  #might be overkill but it really tests out the pipeline :)
  #
  describe 'when boundary times are not specified' do
    let (:url) {'https://localhost:3030'}
    let(:key) {'EuOjCqFd4lpin7U-oPApNiQTReO6HaQUxfnkLZglkYQ'}
    let(:user) {create(:user)}

    it 'updates the streams', :vcr do
      @adapter = Joule::Adapter.new(url, key)
      service = CreateNilm.new(@adapter)
      service.run(name: 'test', url: url, owner: user, key:key)
      events1 = EventStream.find_by_path("/Homes/AB Transients")
      events2 = EventStream.find_by_path("/basic/aux/events0")
      service = ReadEvents.new
      service.run([{stream:events1, filter:[]}, {stream:events2, filter:[]}], nil, nil)
      #bounds taken from test joule on vagrant instance
      # AB Transients: [1564632656344436 - 1564637216855134]
      # events 0 - no events
      expect(service.start_time).to eq(1564632656344436)
      expect(service.end_time).to eq(1564637216855134)
      #check the events
      expect(service.data.length).to eq 2
      if service.data[0][:id] == events1.id
        rx_events1 = service.data[0][:events]
        rx_events2 = service.data[1][:events]
      else
        rx_events1 = service.data[1][:events]
        rx_events2 = service.data[0][:events]
      end
      expect(rx_events2.length).to eq 0
      expect(rx_events1.length).to eq 21
      expect(rx_events1[0][:start_time]).to eq service.start_time
      expect(rx_events1[0][:start_time]).to eq service.start_time
      expect(rx_events1[-1][:content][:height]).to eq -1028.9400634765625

    end
  end
end
