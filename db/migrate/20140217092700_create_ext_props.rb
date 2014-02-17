class CreateExtProps < ActiveRecord::Migration
  def change
    create_table :ext_props do |t|
      t.string :title
      t.string :value
      t.references :product, index: true

      t.timestamps
    end
  end
end
