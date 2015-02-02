require 'date'

class LobbyController < ApplicationController
  before_filter :not_signed_in
  #before_filter :upd_inactive_games

  ##@@count = 0

  def index
    ##@@count = @@count + 1
    #@count = @@count
    clear_player
  	@players = Player.where(['last_seen > ?', Time.now-IDLE_TIME])
  end

  # define helper 
  def not_signed_in
  	if not player_signed_in?
  		 redirect_to new_player_session_path
  	end
  end

  def clear_player
    current_player.update_attributes(:available => true)
    current_player.update_attributes(:my_card => "")
    current_player.update_attributes(:game_id => nil)
  end

  def upd_inactive_games 
    Game.all.find_each do |g|
      if (g.player_list.length != 0)
        p_list = JSON.parse(g.player_list)
        upd_p_list = JSON.parse(g.player_list)
        p_list.each do |p|
          play = Player.where(['email = ?', p])
          if (play[0].last_seen < Time.now-50)
            play[0].update_attributes(:game_id => nil)
            upd_p_list.delete(p) 
            g.update_attributes(:player_list => JSON.dump(upd_p_list))
          end 
        end
        if upd_p_list.length <= 0
          g.destroy
        end 
      elsif (g.player_list.length == 0)
        g.destroy
      end
    end
  end

end
