class GamesController < ApplicationController
	def create 
		@game = Game.new(state:1)
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
