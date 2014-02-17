class CreatePrices < ActiveRecord::Migration
  def change
    create_table :prices do |t|
      t.float :cost
      t.references :product, index: true

      t.timestamps
    end
  end
end
