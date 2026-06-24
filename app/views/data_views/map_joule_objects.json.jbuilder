json.data do
  json.object_map do
    json.nilm @nilm.id
    json.db_folders @folders do |db_folder|
      json.id db_folder.id
      json.joule_id db_folder.joule_id
    end
    json.db_streams @data_streams do |db_stream|
      json.id db_stream.id
      json.joule_id db_stream.joule_id
    end
    json.event_streams @event_streams do |event_stream|
      json.id event_stream.id
      json.joule_id event_stream.joule_id
    end
  end
  json.db_folders @folders do |db_folder|
    json.partial! 'db_folders/db_folder', db_folder: db_folder, nilm: @nilm
  end
end

json.partial! "helpers/messages", service: @service