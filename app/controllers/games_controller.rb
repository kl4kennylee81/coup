class GamesController < ApplicationController
	def create 
		init_player_list = JSON.generate [current_player]
		@game = Game.new(state:1,player_list:init_player_list)
		@game.save
		current_player.update_attributes(:available => false)
		redirect_to @game
	end

	def show
		@game = Game.find(params[:id])
		current_player.update_attributes(:game_id => @game.id)
  		@players = Player.where(['game_id = ?', @game.id])
	end
end
