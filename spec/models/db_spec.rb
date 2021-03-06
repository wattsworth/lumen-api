# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Db' do
  describe 'object' do
    let(:db) { Db.new }
    specify { expect(db).to respond_to(:url) }
    specify { expect(db).to respond_to(:root_folder) }

    specify { expect(db).to respond_to(:available) }
    specify { expect(db).to respond_to(:size_db) }
    specify { expect(db).to respond_to(:size_total) }
    specify { expect(db).to respond_to(:size_other) }
    specify { expect(db).to respond_to(:version) }
    specify { expect(db).to respond_to(:max_points_per_plot) }

  end

  it 'removes the root folder when destroyed' do
    root_folder = DbFolder.create
    db = Db.create(root_folder: root_folder)
    db.destroy
    expect(DbFolder.find_by_id(root_folder.id)).to be nil
  end

  #TODO: nilms will only have joule endpoint
  describe 'url' do
    it 'can be customized' do
      db_x = Db.create(url: 'custom_string')
      expect(db_x.url).to eq('custom_string')
    end
    it 'can be left as default' do
      nilm = Nilm.create(url: 'base')
      db_x = Db.new(nilm: nilm, url: '')
      expect(db_x.url).to eq('base')
    end
  end
end
