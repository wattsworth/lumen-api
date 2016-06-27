# frozen_string_literal: true

# Database object
class Db < ActiveRecord::Base
  belongs_to :root_folder, foreign_key: 'db_folder_id', class_name: 'DbFolder'
  belongs_to :nilm

  def url
    # return a custom URL if set
    return @url unless @url.nil? || @url.empty?
    # no default URL if no parent NILM available
    return '--error, no parent NILM--' if nilm.nil?
    # return the default URL"
    "#{nilm.url}/nilmdb"
  end

  def as_json(options = {})
    db = super(except: [:created_at, :updated_at])
    db[:contents] = root_folder.as_json(options)
    db
  end
end