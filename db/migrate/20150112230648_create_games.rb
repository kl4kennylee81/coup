class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.string :cards
      t.string :player_list
      t.integer :state
      t.integer :current_turn

      t.timestamps null: false
    end
  end
end
