class AddNodeNameToNilm < ActiveRecord::Migration[8.1]
  def change
        add_column :nilms, :node_uuid, :string
  end
end
