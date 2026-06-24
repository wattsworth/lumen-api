# frozen_string_literal: true

# Given the Joule ID's return the API ID's
# See /folder/map.json route in Joule
class MapJouleObjects
  include ServiceStatus
  attr_reader :folders, :data_streams, :event_streams

  def run(nilm, folder_ids, data_stream_ids, event_stream_ids)
    @folders = DbFolder.where(db: nilm.db, joule_id: folder_ids)
    @data_streams = DbStream.where(db: nilm.db, joule_id: data_stream_ids)
    @event_streams = EventStream.where(db: nilm.db, joule_id: event_stream_ids)
  end
end

