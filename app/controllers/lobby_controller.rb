class LobbyController < ApplicationController
  before_filter :helper

  def index
  	current_player.update_attributes(:available => true)
    current_player.update_attributes(:game_id => nil)
  	@players = Player.where(['last_seen > ?', Time.now-IDLE_TIME])
  end

  # define helper 
  def helper
  	if not player_signed_in?
  		 redirect_to new_player_session_path
  	end
  end
end
