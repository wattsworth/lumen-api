# frozen_string_literal: true
json.data do
  json.extract! @nilm, *Nilm.json_keys
  json.role @role
  if @nilm.db != nil
    json.max_points_per_plot @nilm.db.max_points_per_plot
    json.max_events_per_plot @nilm.db.max_events_per_plot
    json.version = @nilm.db.version
    json.size_db = @nilm.db.size_db
    json.size_other = @nilm.db.size_other
    json.size_total = @nilm.db.size_total
    json.available @nilm.db.available
    json.root_folder do
      if @nilm.db.root_folder != nil
        json.partial! 'db_folders/db_folder',
                      db_folder: @nilm.db.root_folder,
                      nilm: @nilm
      end
    end
  end
  json.data_apps(@nilm.data_apps) do |app|
    json.id app.id
    json.name app.name
    json.url "" # this can be retrieved with data_app#show
    json.nilm_id @nilm.id
  end
end
json.partial! 'helpers/messages', service: @service
