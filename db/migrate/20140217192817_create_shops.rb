class CreateShops < ActiveRecord::Migration
  def change
    create_table :shops do |t|
      t.string :title
      t.string :xpath
      t.string :url
      t.string :host

      t.timestamps
    end
  end
end
