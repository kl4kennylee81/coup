class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.string :cards
      t.string :player_list
      t.integer :state
      t.integer :current_turn

      #game logic
      t.boolean  :assas,                 default: false
      t.boolean  :duke,                  default: false
      t.boolean  :ambs,                  default: false
      t.boolean  :cap,                   default: false
      t.boolean  :fa,                    default: false
      t.boolean  :inc,                   default: false
      t.boolean  :coup,                  default: false 
      t.boolean  :target,                default: false
      t.string   :bs,                    default: ""
      t.string   :coin_list,              default: ""
      t.boolean  :counter,               default: false
      t.boolean  :contessa,              default: false

      t.timestamps null: false
    end
  end
end
