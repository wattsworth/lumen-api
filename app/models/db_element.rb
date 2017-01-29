# frozen_string_literal: true

# a column in a stream, this is the lowest element
# in the db hierarchy and contains actual data
class DbElement < ApplicationRecord
  belongs_to :db_stream

  validates :name, presence: true
  validates :name, uniqueness: { scope: :db_stream_id,
    message: ' is already used in this folder'}

  validates :scale_factor, presence: true, numericality: true
  validates :scale_factor, presence: true, numericality: true
  validates :default_min, allow_nil: true, numericality: true
  validates :default_max, allow_nil: true, numericality: true

  # force set any validated params to acceptable
  # default values this allows us to process corrupt databases
  def use_default_attributes
    self.name = "element#{self.column}"
    self.units = ""
    self.default_min = nil
    self.default_max = nil
    self.scale_factor = 1.0
    self.offset = 0.0
  end

  def as_json(_options = {})
    super(except: [:created_at, :updated_at])
  end
end