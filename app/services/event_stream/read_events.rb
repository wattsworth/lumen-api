# frozen_string_literal: true

# Handles changing DbStream attributes
class ReadEvents
  include ServiceStatus
  attr_reader :data, :start_time, :end_time

  def initialize()
    super()

  end

  def run(event_streams, start_time, end_time)
    @start_time = start_time
    @end_time = end_time
    if (not @start_time.nil?) and (not @end_time.nil?) and (@start_time > @end_time)
      add_error("invalid time bounds")
      return self
    end
    # pull data from streams
    @data = []
    event_streams.each do |stream|
      adapter = NodeAdapterFactory.from_nilm(stream.db.nilm)
      result = adapter.read_events(stream, @start_time, @end_time)
      if not result.nil?
        @data.append(result)
      else
        @data.append({id: stream.id, valid: false, events: nil})
        add_warning("unable to retrieve events for #{stream.path}")
      end
    end
    # set the time boundaries if they were nil
    @start_time = @start_time.nil? ? _data_start : @start_time
    @end_time = @end_time.nil? ? _data_end : @end_time
    self
  end


  def _data_start
    min_start = nil
    @data.each do |event_stream|
      next unless event_stream[:valid]
      next unless event_stream[:events].length > 0
      first_event=event_stream[:events][0]
      first_time = first_event[:start_time]
      min_start = min_start.nil? ? first_time : [first_time,min_start].min
    end
    min_start
  end

  def _data_end
    max_end = nil
    @data.each do |event_stream|
      next unless event_stream[:valid]
      next unless event_stream[:events].length > 0
      last_event=event_stream[:events][-1]
      last_time = last_event[:end_time].nil? ? last_event[:start_time] : last_event[:end_time]
      max_end = max_end.nil? ? last_time : [last_time,max_end].max
    end
    max_end
  end
end
