# frozen_string_literal: true

# NILM object
class Nilm < ApplicationRecord

  #---Associations-----
  has_one :db, dependent: :destroy
  has_many :permissions, dependent: :destroy #viewer, owner, admin
  has_many :users, through: :permissions
  has_many :user_groups, through: :permissions
  has_many :data_views_nilms
  has_many :data_views, through: :data_views_nilms
  has_many :data_apps, dependent: :destroy
  #---Validations-----
  validates :name, presence: true, uniqueness: true
  validates :url, presence: true, uniqueness: true
  validates :node_type, presence: true,
            inclusion: { in: %w(nilmdb joule) }
  #---Callbacks------
  before_destroy do |record|
    DataView.destroy(record.data_views.pluck(:id))
  end

  def self.json_keys
    [:id, :name, :description, :url, :node_uuid]
  end

end
