class GamesController < ApplicationController

	@@assas = false
	@@duke = false
	@@ambs = false
	@@cap = false
	@@fa = false
	@@inc = false
	@@coup = false 
	@@target = ""
	@@bs = []
	@@counter = false
	@@contessa = false

	def create 
		# hack to coerce JSON.dump to create an array with one object
		temp_list = Array.new(0)
		init_player_list = JSON.dump (temp_list)
		@game = Game.new(state:1,player_list:init_player_list)
		@game.save
		current_player.update_attributes(:available => false)
		redirect_to @game
	end

	def show
		@game = Game.find(params[:id])
		@cur_plist = JSON.parse (@game.player_list)
		@added_player = player_join(@cur_plist,current_player.email)
		@game.update_attributes(player_list:JSON.dump(@added_player))
		current_player.update_attributes(:game_id => @game.id)
  		@players = Player.where(['game_id = ?', @game.id])
  		if (@game.state >= 2)
  			@is_turn = your_turn(@cur_plist,@game.current_turn)
  			@current_turn = @cur_plist[@game.current_turn-1]
  			@last_turn = last_move
  			@bull = @@bs
  			@can_call = can_call_bs(current_player.email)
  			@can_counter = can_counter(@can_call,@game.state)
  			@iscapt = @@cap
  			@targ = @@target
  		end
	end

	def update 
		@game = Game.find(params[:id])
		cur_plist = JSON.parse (@game.player_list)
		if ((cur_plist.length > 0)&&@game.state<2)
			clear_moves
			@game.update_attributes(:state => 2)
			shuffled = string_shuffle(CARDS)
			deck_list = shuffled.scan(/./)
			cur_plist.each do |p|
				play = Player.where(['email = ?', p])
				cards = deck_list.pop()
				cards = cards + deck_list.pop()
				play[0].update_attributes(:my_card => cards)
			end 
			@game.update_attributes(:cards => shuffled)
			cur_plist.shuffle!
			upd_list = JSON.dump(cur_plist)
			@game.update_attributes(:player_list => upd_list)
			@game.update_attributes(:current_turn => 1)
			redirect_to @game
		elsif params[:move] && (@game.state == 2)
			update_move(params[:move],params[:target])
			update_turn = next_turn(cur_plist,@game.current_turn)
			@@bs = check_bs(cur_plist,@game.state)
			ifcounter = can_counter(true,@game.state)
			if (skip_steps)
				clear_moves
				@game.update_attributes(:current_turn => update_turn)
				@game.update_attributes(:state => 2)
				redirect_to @game
			else
				@game.update_attributes(:state => 3)
				redirect_to @game
			end
			
		elsif (@game.state == 3) 
			#calling bs
			#process the effect of move
			if params[:block]
				add_blocker(params[:block])
				@@target = cur_plist[@game.current_turn-1]
				@game.update_attributes(:state => 4)
				@@bs = check_bs(cur_plist,@game.state)
				redirect_to @game
			elsif params[:bs]
				clear_moves
				update_turn = next_turn(cur_plist,@game.current_turn)
				@game.update_attributes(:current_turn => update_turn)
				@game.update_attributes(:state => 2)
				redirect_to @game
			else 
				clear_moves
				update_turn = next_turn(cur_plist,@game.current_turn)
				@game.update_attributes(:current_turn => update_turn)
				@game.update_attributes(:state => 2)
				redirect_to @game
			end
		elsif (@game.state == 4)&&params[:bs]
			clear_moves
			update_turn = next_turn(cur_plist,@game.current_turn)
			@game.update_attributes(:current_turn => update_turn)
			@game.update_attributes(:state => 2)
			redirect_to @game
		#put a warning to have at least 2 players
		end
	end  

	#game state functions 

	##helper functions


	def skip_steps
		if @@coup||@@inc
			return true
		else
			false
		end
	end

	def add_blocker(blocking)
		if @@assas
			@@counter = false
			@@assas = false
			@@contessa = true
		elsif @@cap&&(blocking == "captain")
			@@counter = false
		elsif @@cap
			@@counter = false
			@@cap = false
			@@ambs = true
		elsif @@fa
			@@counter = false
			@@fa = false
			@@duke = true
		end
	end

	def clear_moves
		@@assas = false
		@@duke = false
		@@ambs = false
		@@cap = false
		@@fa = false
		@@inc = false
		@@coup = false 
		@@target = ""
		@@bs = []
		@@counter = false
		@@contessa = false
	end


	def can_counter(cancall,state)
		if (state == 4)
			return false
		elsif ((@@cap||@@assas)&&(cancall))||(@@fa)
			return true
		else
			return false
		end
	end

	def can_call_bs(name)
		finding = @@bs.find_index(current_player.email)
		if (finding == nil)
			return false
		else
			true
		end
	end

	def check_bs(li,state)
		if @@assas||@@cap
			return [@@target]
		elsif @@inc||@@coup||@@fa||@@inc
			return []
		elsif (@@contessa||@@cap||@@ambs||@@duke)&&(state == 4)
			return [@@target]
		else
			return li
		end
	end

	def check_counter
		if @@assas||@@cap||@@fa
			return true
		else 
			false
		end
	end

	def update_move (move, t="")
		if move == "income"
			@@inc = true
		elsif move == "fa"
			@@fa = true
		elsif move == "coup"
			@@coup = true
		elsif move == "duke"
			@@duke = true
		elsif move == "ambassador"
			@@ambs = true
		elsif move == "assassin"
			@@assas = true
		elsif move == "captain"
			@@cap = true
		end

		if (t != "")&&(@@coup||@@assas||@@cap)
			@@target = t
		end
	end 

	def last_move 
		if @@assas
			return "assasinate on "+ @@target
		elsif @@duke
			return "tax"
		elsif @@ambs
			return "exchange"
		elsif @@fa
			return "foreign aid"
		elsif @@coup
			return "coup on "+ @@target
		elsif @@cap
			return "steal on "+ @@target
		elsif @@inc
			return "income"
		else
			return "nothing"
		end
	end

	def next_turn(li,n)
		next_turn = n+1
		if (next_turn >= li.length)
			return 1
		else 
			return next_turn
		end
	end

	def your_turn(li,n)
		name = li[n-1]
		if name = current_player.email
			return true
		else
			return false
		end
	end

	def string_shuffle(s)
  		s.split("").shuffle.join
	end

	def player_ingame (li,x)
		if li.length == 0
			return false
		else
			li.each do |i|
				if (i = x)
					return true
				else
				end
			end
			return false
		end
	end

	def player_join (li,x)
		if player_ingame(li,x)
			return li
		else 
			return li.push(x)
		end
	end
end
