# frozen_string_literal: true

# Wrapper around NilmDB HTTP service
class DbAdapter
  include HTTParty

  def initialize(url)
    @url = url
  end

  def schema # rubocop:disable Metrics/MethodLength
    dump = self.class.get("#{@url}/stream/list?extended=1")
    dump.parsed_response.map do |entry|
      # TODO: implement global metadata dump, because this is sloooow
      dump = self.class.get("#{@url}/stream/get_metadata?path=#{entry[0]}")
      metadata = dump.parsed_response['config_key__']
      { path:       entry[0],
        attributes: {
          data_type:  entry[1],
          start_time: entry[2] || 0,
          end_time:   entry[3] || 0,
          total_rows: entry[4],
          total_time: entry[5]
        }.merge(metadata)
      }
    end
  end
end