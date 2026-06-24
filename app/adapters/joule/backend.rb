#frozen_string_literal: true
module Joule
  # Wrapper around Joule HTTP service
  class Backend
    include HTTParty
    default_timeout 15
    open_timeout 15
    read_timeout 15

    attr_reader :url

    def initialize(url, key)
      @url = url
      self.class.default_options[:headers] = {'X-API-KEY': key}
      self.class.default_options[:verify] = false

      # TODO handle SSL configuration
    end

    def node_info
      begin
        resp = self.class.get("#{@url}/version.json")
        if not resp.success?
          Rails.logger.warn "Error retrieving /version.json for #{@url}: [#{resp.body}]"
          return nil
        end
        version_info = resp.parsed_response
        # if the site exists but is not a nilm...
        required_keys = %w(version uuid)
        unless version_info.respond_to?(:has_key?) &&
            required_keys.all? {|s| version_info.key? s}
          Rails.logger.warn "Error #{@url} is not a Joule node"
          return nil
        end

        resp = self.class.get("#{@url}/dbinfo")
        if not resp.success?
          Rails.logger.warn "Error retrieving /dbinfo for #{@url}: [#{resp.body}]"
          return nil
        end
        db_info = resp.parsed_response
      rescue StandardError => e
        Rails.logger.warn "Error retrieving dbinfo for #{@url}: [#{e}]"
        return nil
      end
      # if the site exists but is not a nilm...
      required_keys = %w(size other free reserved)
      unless db_info.respond_to?(:has_key?) &&
          required_keys.all? {|s| db_info.key? s}
        Rails.logger.warn "Error #{@url} is not a Joule node"
        return nil
      end
      {
          version: version_info['version'],
          uuid: version_info['uuid'],
          size_db: db_info['size'],
          size_other: db_info['other'],
          size_total: db_info['size'] + db_info['other'] + db_info['free'] + db_info['reserved']
      }
    end

    def db_schema
      begin
        resp = self.class.get("#{@url}/folders.json")
        return nil unless resp.success?
      rescue StandardError => e
        Rails.logger.warn "Error retrieving db_schema for #{@url}: [#{e}]"
        return nil
      end
      resp.parsed_response.deep_symbolize_keys
    end

    def app_schemas
      begin
        resp = self.class.get("#{@url}/app.json")
        return nil unless resp.success?
        items = resp.parsed_response
        # if the site exists but is not a joule server...
        required_keys = %w(name id)
        items.each do |item|
          unless item.respond_to?(:has_key?) &&
              required_keys.all? {|s| item.key? s}
            Rails.logger.warn "Error #{@url} is not a Joule node"
            return nil
          end
          item.symbolize_keys!
        end

      rescue StandardError => e
        Rails.logger.warn "Error retrieving app_schemas for #{@url}: [#{e}]"
        return nil
      end
      items
    end

    def module_schemas
      begin
        resp = self.class.get("#{@url}/modules.json?statistics=1")
        return nil unless resp.success?
        items = resp.parsed_response
        # if the site exists but is not a joule server...
        required_keys = %w(name inputs outputs)
        items.each do |item|
          unless item.respond_to?(:has_key?) &&
              required_keys.all? {|s| item.key? s}
            Rails.logger.warn "Error #{@url} is not a Joule node"
            return nil
          end
          item.symbolize_keys!
        end

      rescue StandardError => e
        Rails.logger.warn "Error retrieving module_schemas for #{@url}: [#{e}]"
        return nil
      end
      items
    end


    def module_interface(joule_module, req)
      self.class.get("#{@url}/interface/#{joule_module.joule_id}/#{req}")
    end

    def module_post_interface(joule_module, req, body)
      self.class.post("#{@url}/interface/#{joule_module.joule_id}/#{req}", body: body)
    end

    def stream_info(joule_id)
      begin
        resp = self.class.get("#{@url}/stream.json?id=#{joule_id}")
        return nil unless resp.success?
      rescue
        return nil
      end
      resp.parsed_response.deep_symbolize_keys
    end

    def load_data(joule_id, start_time, end_time, resolution)
      query = {'id': joule_id, 'max-rows': resolution}
      query['start'] = start_time unless start_time.nil?
      query['end'] = end_time unless end_time.nil?
      options = {query: query}
      begin
        resp = self.class.get("#{@url}/data.json", options)
        if resp.code == 400 and resp.body.include?('decimated data is not available')
          return {success: false, result: "decimation error"}
        end
        return {success: false, result: resp.body} unless resp.success?
      rescue
        return {success: false, result: "connection error"}
      end
      {success: true, result: resp.parsed_response.symbolize_keys}
    end

    def load_intervals(joule_id, start_time, end_time)
      query = {'id': joule_id}
      query['start'] = start_time unless start_time.nil?
      query['end'] = end_time unless end_time.nil?
      options = {query: query}
      begin
        resp = self.class.get("#{@url}/data/intervals.json", options)
        return {success: false, result: resp.body} unless resp.success?
      rescue
        return {success: false, result: "connection error"}
      end
      data = []
      resp.parsed_response.each do |interval|
        data.push([interval[0], 0])
        data.push([interval[1], 0])
        data.push(nil) # break up the intervals
      end
      {success: true, result: data}
    end

    def update_stream(db_stream)
      elements = []
      db_stream.db_elements.each do |elem|
        elements << {name: elem.name,
                     plottable: elem.plottable,
                     units: elem.units,
                     default_min: elem.default_min,
                     default_max: elem.default_max,
                     scale_factor: elem.scale_factor,
                     offset: elem.offset,
                     display_type: elem.display_type}
      end

      attrs = {name: db_stream.name,
               description: db_stream.description,
               elements: elements
      }
      begin
        response = self.class.put("#{@url}/stream.json",
                                  headers: {'Content-Type' => 'application/json'},
                                  body: {
                                      id: db_stream.joule_id,
                                      stream: attrs}.to_json)
      rescue
        return {error: true, msg: 'cannot contact Joule server'}
      end
      unless response.success?
        return {error: true, msg: "error updating #{db_stream.path} metadata"}
      end
      {error: false, msg: 'success'}
    end

    def update_folder(db_folder)
      attrs = {name: db_folder.name,
               description: db_folder.description}
      begin
        response = self.class.put("#{@url}/folder.json",
                                  headers: {'Content-Type' => 'application/json'},
                                  body: {
                                      id: db_folder.joule_id,
                                      folder: attrs}.to_json)
      rescue
        return {error: true, msg: 'cannot contact Joule server'}
      end
      unless response.success?
        return {error: true, msg: "error updating #{db_folder.path} metadata"}
      end
      {error: false, msg: 'success'}
    end

    # === EVENT METHODS ===
    def read_events(stream_id, max_events, start_time, end_time, filter)
      query = {'id': stream_id}
      query['start'] = start_time unless start_time.nil?
      query['end'] = end_time unless end_time.nil?
      query['limit'] = max_events
      query['filter'] = filter.to_json unless filter.nil?
      query['include-ongoing-events'] = 1
      options = {query: query}
      begin
        resp = self.class.get("#{@url}/event/data.json", options)
        raise "error reading events #{resp.body}" unless resp.success?
      rescue
        raise "connection error"
      end
      if resp.parsed_response.is_a?(Hash)
        resp.parsed_response.deep_symbolize_keys!
        resp
      else # backwards compatibility
        events = resp.parsed_response.map{|event| event.deep_symbolize_keys}
        count = if events.nil? then 0 else events.length end
        {count: count, events: events}
      end
    end
    # === ANNOTATION METHODS ===
    def create_annotation(annotation)
      data = {
          'stream_id': annotation.db_stream.joule_id,
          'title': annotation.title,
          'content': annotation.content,
          'start': annotation.start_time,
          'end': annotation.end_time}
      begin
        resp = self.class.post("#{@url}/annotation.json",
                               headers: {'Content-Type' => 'application/json'},
                               body: data.to_json)
        raise "error creating annotations #{resp.body}" unless resp.success?
      rescue
        raise "connection error"
      end
      annotation.id = resp.parsed_response["id"]
      annotation
    end

    def get_annotations(stream_id)
      query = {'stream_id': stream_id}
      options = {query: query}
      begin
        resp = self.class.get("#{@url}/annotations.json", options)
        raise "error loading annotations #{resp.body}" unless resp.success?
      rescue
        raise "connection error"
      end
      resp.parsed_response
    end

    def delete_annotation(annotation_id)
      query = {'id': annotation_id}
      options = {query: query}
      begin
        resp = self.class.delete("#{@url}/annotation.json",
                                 options)
        raise "error deleting annotation #{resp.body}" unless resp.success?
      rescue
        raise "connection error"
      end
    end

    def edit_annotation(annotation_id, title, content)
      begin
        resp = self.class.put("#{@url}/annotation.json",
                              headers: {'Content-Type' => 'application/json'},
                              body: {id: annotation_id,
                                     title: title,
                                     content: content}.to_json)
        raise "error updating annotation #{resp.body}" unless resp.success?

      rescue
        raise "connection error"
      end
      resp.parsed_response
    end

    # === END ANNOTATION METHODS ===
  end
end
