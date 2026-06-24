# frozen_string_literal: true
module Joule
  # Handles construction of database objects
  class UpdateDb
    include ServiceStatus

    def initialize(db)
      @db = db
      @deleted_folders = []
      @deleted_db_streams = []
      @deleted_event_streams = []
      super()
    end

    def run(schema)
      # reset the accumulator arrays
      @deleted_event_streams = []
      @deleted_db_streams = []
      @deleted_folders = []
      # go through the schema and update the database
      @db.root_folder ||= DbFolder.create(db: @db)
      __update_folder(@db.root_folder, schema, '')
      if not schema[:active_data_streams].nil?
        active_stream_ids = schema[:active_data_streams]
        # activate currently inactive streams
        DbStream.where(db_id: @db.id, active: false, joule_id: active_stream_ids).update(active: true)
        # deactivate streams that are no longer active
        DbStream.where(db_id: @db.id, active: true).where.not(joule_id: active_stream_ids).update(active: false)
      end
      DbStream.destroy(@deleted_db_streams)
      EventStream.destroy(@deleted_event_streams)
      DbFolder.destroy(@deleted_folders)

      @db.available = true
      @db.save
      self
    end

    def __update_folder(db_folder, schema, parent_path)
      attrs = schema.slice(*DbFolder.defined_attributes)
      # check to see if this db_folder has changed since last update
      # only do this if the joule node supports timestamps
      if not schema[:updated_at].nil?
        attrs[:last_update] = schema[:updated_at].to_datetime
        if db_folder.last_update >= attrs[:last_update]
          return puts "ignoring #{db_folder.name}:#{db_folder.id}, #{db_folder.last_update}>#{schema[:updated_at]} "
        end
      end
      if db_folder.id.nil?
        puts "creating #{schema[:name]}"
      else
        puts "updating #{db_folder.name}:#{db_folder.id}"
      end

      # add in extra attributes that require conversion
      if db_folder.parent.nil?
        attrs[:path] = ""
      else
        attrs[:path] = "#{parent_path}/#{schema[:name]}"
      end
      attrs[:joule_id] = schema[:id]
      attrs[:hidden] = false
      db_folder.update(attrs)
      unless db_folder.valid?
        if db_folder.errors.messages.keys.include?(:name) \
          and db_folder.errors.messages[:name][0].include?("already used")
          db_folder.parent.subfolders.where(name: db_folder.name).update(name: "#{db_folder.name}__#{rand}")
          # try to save again
          db_folder.update!(attrs)
        end
      end
      #puts db_folder.parent.id
      # update or create subfolders
      updated_ids = []
      size_on_disk = 0
      start_time = nil
      end_time = nil
      locked = false
      schema[:children].each do |child_schema|
        child = db_folder.subfolders.find_by_joule_id(child_schema[:id])
        if child.nil? # check to see if this folder has been moved from a different location
          child = @db.db_folders.find_by_joule_id(child_schema[:id])
          if not child.nil?
            child.parent = db_folder
            puts "moved #{child.name} to #{db_folder.name}"
            @deleted_folders = @deleted_folders - [child.id]
          end
        end
        child ||= DbFolder.new(parent: db_folder, db: db_folder.db)
        __update_folder(child, child_schema, db_folder.path)
        size_on_disk+=child.size_on_disk unless child.size_on_disk.nil?
        unless child.start_time.nil?
          if start_time.nil?
            start_time = child.start_time
          else
            start_time = [child.start_time, start_time].min
          end
        end
        unless child.end_time.nil?
          if end_time.nil?
            end_time = child.end_time
          else
            end_time = [child.end_time, end_time].max
          end
        end
        updated_ids << child_schema[:id]
        locked = true if child.locked?
      end
      # mark any subfolders that are no longer in the folder for deletion
      @deleted_folders += db_folder.subfolders.where.not(joule_id: updated_ids).pluck(:id)

      # update or create data streams
      updated_ids=[]
      schema[:streams].each do |stream_schema|
        stream = db_folder.db_streams.find_by_joule_id(stream_schema[:id])
        if stream.nil? # check to see if this stream has been moved from a different location
          stream = @db.db_streams.find_by_joule_id(stream_schema[:id])
          if not stream.nil?
            stream.db_folder = db_folder
            puts "moved #{stream.name} to #{db_folder.name}"
            @deleted_db_streams = @deleted_db_streams - [stream.id]
          end
        end
        stream ||= DbStream.new(db_folder: db_folder, db: db_folder.db)
        puts "Updating #{stream.name}"
        __update_stream(stream, stream_schema, db_folder.path)
        size_on_disk+=stream.size_on_disk unless stream.size_on_disk.nil?
        unless stream.start_time.nil?
          if start_time.nil?
            start_time = stream.start_time
          else
            start_time = [stream.start_time, start_time].min
          end
        end
        unless stream.end_time.nil?
          if end_time.nil?
            end_time = stream.end_time
          else
            end_time = [stream.end_time, end_time].max
          end
        end
        locked=true if stream.locked?
        updated_ids << stream_schema[:id]
      end
      # mark any db streams that are no longer on the folder for deletion
      @deleted_db_streams += db_folder.db_streams.where.not(joule_id: updated_ids).pluck(:id)

      # update or create event streams
      updated_ids=[]
      schema[:event_streams] ||= []
      schema[:event_streams].each do |stream_schema|
        stream = db_folder.event_streams.find_by_joule_id(stream_schema[:id])
        if stream.nil? # check to see if this stream has been moved from a different location
          stream = @db.event_streams.find_by_joule_id(stream_schema[:id])
          if not stream.nil?
            stream.db_folder = db_folder
            puts "moved #{stream.name} to #{db_folder.name}"
            @deleted_event_streams = @deleted_event_streams - [stream.id]
          end
        end
        stream ||= EventStream.new(db_folder: db_folder, db: db_folder.db)

        __update_event_stream(stream, stream_schema, db_folder.path)
        updated_ids << stream_schema[:id]
      end

      # mark any event streams that are no longer in the folder for deletion
      @deleted_event_streams += db_folder.event_streams.where.not(joule_id: updated_ids).pluck(:id)

      # save the new disk size
      db_folder.size_on_disk = size_on_disk
      db_folder.start_time = start_time
      db_folder.end_time = end_time
      db_folder.locked = locked
      db_folder.save
    end

    def __update_stream(db_stream, schema, parent_path)
      attrs = schema.slice(*DbStream.defined_attributes)
      # check to see if this stream has changed since last update
      # only do this if the joule node supports timestamps
      if not schema[:updated_at].nil?
        attrs[:last_update] = schema[:updated_at].to_datetime
        if db_stream.last_update >= attrs[:last_update]
          return puts "ignoring Stream #{db_stream.name}:#{db_stream.id}, #{db_stream.last_update}>#{schema[:updated_at]} "
        end
      end
      # add in extra attributes that require conversion
      attrs[:path] = "#{parent_path}/#{schema[:name]}"
      attrs[:data_type] = "#{schema[:datatype].downcase}_#{schema[:elements].count}"
      attrs[:joule_id] = schema[:id]
      if schema.has_key?(:data_info)
        attrs[:start_time] = schema[:data_info][:start]
        attrs[:end_time] = schema[:data_info][:end]
        attrs[:total_rows] = schema[:data_info][:rows]
        attrs[:total_time] = schema[:data_info][:total_time]
        attrs[:size_on_disk] = schema[:data_info][:bytes]
      end
      db_stream.update(attrs)
      # check if model has a unique name, if not rename the conflicting
      # stream which should be flagged for deletion later
      unless db_stream.valid?
        if db_stream.errors.messages.keys.include?(:name) \
          and db_stream.errors.messages[:name][0].include?("already used")
          db_stream.db_folder.db_streams.where(name: db_stream.name).update(name: "#{db_stream.name}__#{rand}")
          # try to save again
          db_stream.update!(attrs)
        end
      end
      #db_stream.db_elements.destroy_all
      schema[:elements].each do |element_config|
        element = db_stream.db_elements.find_by_column(element_config[:index])
        element ||= DbElement.new(db_stream: db_stream)
        attrs = element_config.slice(*DbElement.defined_attributes)
        # add in extra attributes that require conversion
        attrs[:display_type] = element_config[:display_type].downcase
        attrs[:column] = element_config[:index]
        attrs[:plottable] = true
        element.update(attrs)
      end
    end

    def __update_event_stream(event_stream, schema, parent_path)
      attrs = schema.slice(*EventStream.defined_attributes)
      # add in extra attributes that require conversion
      attrs[:path] = "#{parent_path}/#{schema[:name]}"
      attrs[:joule_id] = schema[:id]
      if schema.has_key?(:data_info)
        attrs[:start_time] = schema[:data_info][:start]
        attrs[:end_time] = schema[:data_info][:end]
        attrs[:event_count] = schema[:data_info][:event_count]
      end
      attrs[:event_fields_json] = schema[:event_fields].to_json
      event_stream.update(attrs)
      # check if model has a unique name, if not rename the conflicting
      # stream which should be flagged for deletion later
      unless event_stream.valid?
        if event_stream.errors.messages.keys.include?(:name) \
          and event_stream.errors.messages[:name][0].include?("already used")
          event_stream.db_folder.event_streams.where(name: event_stream.name).update(name: "#{event_stream.name}__#{rand}")
          # try to save again
          event_stream.update!(attrs)
        end
      end
    end


  end
end
