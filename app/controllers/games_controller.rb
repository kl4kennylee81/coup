class GamesController < ApplicationController

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
		if (@game.state == 1)
			@cur_plist = JSON.parse (@game.player_list)
			@added_player = player_join(@cur_plist,current_player.email)
			@game.update_attributes(player_list:JSON.dump(@added_player))
			current_player.update_attributes(:game_id => @game.id)
		    @players = Player.where(['game_id = ?', @game.id])
		elsif (@game.state < 6)
			@cur_plist = JSON.parse (@game.player_list)
	  		@players = Player.where(['game_id = ?', @game.id])
	  		@can_target = Player.where(['game_id = ?', @game.id])
	  		@can_target.delete(current_player)
	  		if (@game.state >= 2)&&(@cur_plist.find_index(current_player.email)!= nil)
	  			@is_turn = your_turn(@cur_plist,@game.current_turn)
	  			@current_turn = @cur_plist[@game.current_turn-1]
	  			@last_turn = last_move(@game)
	  			@bull = @game.bs
	  			@can_call = can_call_bs(current_player.email,@game)
	  			@can_counter = can_counter(@can_call,@game.state,@game)
	  			@targ = @game.target
	  			if (@game.state == 2)&&(@is_turn)
	  				@poss_moves = possible_moves(@game)
	  			elsif (@game.state == 5)&&(@is_turn)
	  				all_cards =  @game.drawn+current_player.my_card
	  				@cards_drawn = ambs_combo(all_cards,current_player.my_card.length,[])
	  			end
	  		end
	  	else
	  		@winner = JSON.parse(@game.player_list)[0]
	  	end
	end

	def possible_moves(g)
		p_list = JSON.parse(g.player_list)
		index = p_list.find_index(current_turn_player(@game).email)
		coins = JSON.parse(g.coin_list)[index]
		temp_list = []
		count = 0
		COST_FOR_MOVES.each do |cost|
			if cost<=coins
				temp_list.push(MOVE_LIST[count])
				count = count + 1
			else
				count = count +1
			end
		end
		return temp_list
	end

	def ambs_combo (cards,num,list)
		if (cards.length == 0)
			return list
		else 
			range_end = cards.length - 1
			first = cards[0..0]
			subcards = cards.slice(1..range_end)
			list_cards = list
			if (num == 2)
				subcards.chars.each do |c|
					list_cards.push(first+c)
				end
				return ambs_combo(subcards,num,list_cards)
			else 				
				return ambs_combo(subcards,num,list_cards)
			end
		end
	end

	def update 
		@game = Game.find(params[:id])
		cur_plist = JSON.parse (@game.player_list)
		if ((cur_plist.length > 0)&&@game.state<2)
			init_game(@game)
			redirect_to @game
		elsif params[:move] && (@game.state == 2)
			update_move(params[:move],params[:target],@game)
			@game.update_attributes(:bs => check_bs(cur_plist,@game.state,@game))
			if (skip_steps(@game))
				handle_move_1(@game,@game.target)	
				end_turn(@game)
				redirect_to @game
			else
				@game.update_attributes(:state => 3)
				redirect_to @game
			end
			
		elsif (@game.state == 3) 
			#calling bs
			#process the effect of move
			if params[:block]&&(params[:block] != "nothing")&&(params[:block] != "called")
				add_blocker(params[:block],@game)
				@game.update_attributes(:final_t => @game.target)
				@game.update_attributes(:target => cur_plist[@game.current_turn-1])
				@game.update_attributes(:state => 4)
				@game.update_attributes(:bs => check_bs(cur_plist,@game.state,@game))
				redirect_to @game
			elsif params[:block] == "called"
				#check if bs call was correct
				handle_bluff(@game,current_turn_player(@game),current_player)
			else 
				check_all_called(@game)
			end
		elsif (@game.state == 4)&&params[:block]
				if params[:block] == "called"
					handle_bluff_4(@game,current_player,current_turn_player(@game))
				else 
					end_turn(@game)
					redirect_to @game
				end
		elsif (@game.state == 5)&&params[:chosen]
			picked = params[:chosen]
			exchange(@game,picked,string_diff(@game,picked))
			end_turn(@game)
			redirect_to @game
		#put a warning to have at least 2 players
		end
	end 

	def remove_defeated(g)
		plist = JSON.parse(g.player_list)
		temp_list = []
		plist.each do |p|
 			temp_p = Player.where(['email = ?', p])[0]
 			if (temp_p.my_card.length != 0)
 				temp_list.push(temp_p.email)
 			end
		end
		#if (temp_list.length == 1)
			#g.update_attributes(:player_list => JSON.dump(temp_list))
		#else
		g.update_attributes(:player_list => JSON.dump(temp_list))
		#end
	end

	def check_all_called(g)
		upd_num = g.moves_made + 1
		g.update_attributes(:moves_made => upd_num)
		if all_moved(g)	
			handle_move_1(g,g.target)	
			post_step(g)
		else
			redirect_to g
		end
	end

	def post_step(g)
		if (g.ambs)&&(g.state == 3)
			g.update_attributes(:state => 5)
			redirect_to g
		else
			end_turn(g)
			redirect_to g
		end
	end

	def handle_move_1(g,target) 
		if (g.state == 4)&&(g.contessa)
			assasinate(g,target)
		elsif (g.state == 4)&&((g.cap)||(g.ambs))
			steal(g,target)
		elsif (g.state ==4)&&(g.duke)
			foreign_aid(g)
		elsif g.assas
			assasinate(g,target)
		elsif g.duke
			tax(g)
		elsif g.fa
			foreign_aid(g)
		elsif g.ambs
			ambs_draw(g)
		elsif g.coup
			coup(g,target)
		elsif g.cap
			steal(g,target)
		elsif g.inc
			income(g)
		end
	end

	def handle_bluff_4(g,p1,p2)
		if has_cards(g,p1.email)
			random_delete(p2)
			end_turn(g)
			redirect_to g				
		else
			random_delete(p1)
			handle_move_1(g,g.final_t)
			end_turn(g)
			redirect_to g
		end	
	end

	def ambs_draw (g)
		upd_string = g.cards
 		p = current_turn_player(@game)
		cards = upd_string.slice!(0,p.my_card.length)
		g.update_attributes(:cards => upd_string)
		g.update_attributes(:drawn => cards)
	end

	def string_diff (g,choice)
		switched_out = g.drawn+current_player.my_card
		choice.chars.each do |c|
			index = switched_out.index(c)
			switched_out = switched_out[0,index]+switched_out[index+1..switched_out.length-1]
		end
		return switched_out
	end

	def exchange (g,choice,discard)
		upd_deck = string_shuffle(g.cards+discard)
		g.update_attributes(:cards => upd_deck)
		current_turn_player(g).update_attributes(:my_card => choice)
	end

	def assasinate (g,target)
 		p = Player.where(['email = ?', target])[0]
 		upd_coins = g.coin_list
 		update_coin_list(g,3,current_turn_player(g).email,false)
 		random_delete(p)
	end

	def update_coin_list(g,num,target,isadd)
		coins = JSON.parse(g.coin_list)
		target_index = JSON.parse(g.player_list).find_index(target)
		count = 0
		upd_list = []
		coins.each do |i|
			value = Integer(i)
			if (target_index == count)
				if isadd
					value = value + num
					upd_list.push(value)
				else
					value = value - num
					upd_list.push(value)
				end
			else
				upd_list.push(value)
			end
		end
		string_form = JSON.dump(upd_list)
		g.update_attributes(:coin_list => string_form)
	end

	def tax (g)
 		upd_coins = g.coin_list
 		update_coin_list(g,3,current_turn_player(g).email,true)
	end

	def income (g)
 		upd_coins = g.coin_list
 		update_coin_list(g,1,current_turn_player(g).email,true)
	end 

	def foreign_aid (g)
 		upd_coins = g.coin_list
 		update_coin_list(g,2,current_turn_player(g).email,true)	
	end 

	def steal (g,target)
		cur_plist = JSON.parse(g.player_list)
 		upd_coins = g.coin_list
 		targ_index = cur_plist.find_index(target)
 		targ_coins = JSON.parse(g.coin_list)[targ_index]
 		if (targ_coins < 2)
 			update_coin_list(g,targ_coins,target,false)
 			update_coin_list(g,targ_coins,current_turn_player(g).email,true)
 		else 
 			 update_coin_list(g,2,target,false)
 			update_coin_list(g,2,current_turn_player(g).email,true)
 		end
	end 

	def coup(g,target)
 		p = Player.where(['email = ?', target])[0]
 		upd_coins = g.coin_list
 		update_coin_list(g,7,current_turn_player(g).email,false)
 		random_delete(p)
	end

	def handle_bluff(g,p1,p2)
		if has_cards(g,p1.email)
			random_delete(p2)				
			handle_move_1(g,g.target)
			post_step(g)
		else
			random_delete(p1)
			end_turn(g)
			redirect_to g
		end	
	end

	def random_delete(p)
		cards = p.my_card
		sliced = ""
		if cards.length == 1
			p.update_attributes(:my_card => "")
		elsif cards.length != 0
			sliced = cards[0,1]
			p.update_attributes(:my_card => sliced)
		else
			p.update_attributes(:my_card => "")
		end
	end

	def current_turn_player(g)
		temp_list = JSON.parse(g.player_list)
		name = temp_list[g.current_turn-1]
 		p = Player.where(['email = ?', name])[0]
 		return p
 	end	

	def has_cards(g,name)
 		p = Player.where(['email = ?', name])[0]
 		cards = p.my_card.scan(/./)
		if g.assas&&(cards.find_index('x')!= nil)
			return true
		elsif g.duke&&(cards.find_index('d')!= nil)
			return true
		elsif g.ambs&&(cards.find_index('a')!= nil)
			return true
		elsif g.cap&&(cards.find_index('c')!= nil)
			return true
		elsif g.contessa&&(cards.find_index('l')!= nil)
			return true
		else
			return false
		end
	end



	#do cur_plist.length - 1 after locking the player himself 
	def all_moved (g)
		cur_plist = JSON.parse(g.player_list)
		if g.moves_made >= cur_plist.length
			return true
		else 
			return false
		end
	end

	#game state functions 

	##helper functions

	def end_turn (g)
		remove_defeated(g)
		if (JSON.parse(g.player_list).length <= 1)
			clear_moves(g)
			g.update_attributes(:state => 6)
		else
			cur_plist = JSON.parse (g.player_list)
			clear_moves(g)
			update_turn = next_turn(cur_plist,g.current_turn)
			g.update_attributes(:current_turn => update_turn)
			g.update_attributes(:state => 2)
		end
	end

	def make_hand (p,deck)
		play = Player.where(['email = ?', p])[0]
		cards = deck.pop()
		cards = cards + deck.pop()
		play.update_attributes(:my_card => cards)
	end
	def init_game(g)
		cur_plist = JSON.parse (@game.player_list)
		clear_moves(g)
		g.update_attributes(:state => 2)
		shuffled = string_shuffle(CARDS)
		deck_list = shuffled.scan(/./)
		coin_list = Array.new(cur_plist.length,2)
		g.update_attributes(:coin_list => JSON.dump(coin_list))
		cur_plist.map { |p| make_hand(p,deck_list) }
		g.update_attributes(:cards => list_to_string(deck_list))
		cur_plist.shuffle!
		upd_list = JSON.dump(cur_plist)
		g.update_attributes(:player_list => upd_list)
		g.update_attributes(:current_turn => 1)
	end

	def list_to_string (li)
		string_form = li.join(",")
		string_no_delim = string_form.delete ","
		return string_no_delim
	end


	def string_shuffle(s)
  		s.split("").shuffle.join
	end

	def skip_steps(g)
		if g.coup||g.inc
			return true
		else
			false
		end
	end

	def add_blocker(blocking,g)
		if g.assas
			g.update_attributes(:counter => false)
			g.update_attributes(:assas => false)
			g.update_attributes(:contessa => true)
		elsif g.cap&&(blocking == "captain")
			g.update_attributes(:counter => false)
		elsif g.cap
			g.update_attributes(:counter => false)
			g.update_attributes(:cap => false)
			g.update_attributes(:ambs => true)
		elsif g.fa
			g.update_attributes(:counter => false)
			g.update_attributes(:fa => false)
			g.update_attributes(:duke => true)
		end
	end

	def clear_moves(g)
		g.update_attributes(:assas => false)
		g.update_attributes(:duke => false)
		g.update_attributes(:ambs => false)
		g.update_attributes(:cap => false)
		g.update_attributes(:fa => false)
		g.update_attributes(:inc => false)
		g.update_attributes(:coup => false)
		g.update_attributes(:target => "")
	    g.update_attributes(:final_t => "")
		g.update_attributes(:bs => JSON.dump([]))
		g.update_attributes(:counter => false)
		g.update_attributes(:contessa => false)
		g.update_attributes(:moves_made => 0)
	    g.update_attributes(:drawn => "")
	end

	def can_counter(cancall,state,g)
		if (state == 4)
			return false
		elsif ((g.cap||g.assas)&&(cancall))||(g.fa)
			return true
		else
			return false
		end
	end

	def can_call_bs(name,g)
		list = JSON.parse(g.bs)
		finding = list.find_index(current_player.email)
		if (finding == nil)
			return false
		else
			true
		end
	end

	def check_bs(li,state,g)
		if g.assas||g.cap
			return [g.target]
		elsif g.inc||g.coup||g.fa||g.inc
			return JSON.dump([])
		elsif (g.contessa||g.cap||g.ambs||g.duke)&&(state == 4)
			return JSON.dump([g.target])
		else
			return JSON.dump(li)
		end
	end

	def update_move (move, t="",g)
		if move == "Income"
			g.update_attributes(:inc => true)
		elsif move == "Foreign Aid"
			g.update_attributes(:fa => true)
		elsif move == "Coup"
			g.update_attributes(:coup => true)
		elsif move == "Tax"
			g.update_attributes(:duke => true)
		elsif move == "Exchange"
			g.update_attributes(:ambs => true)
		elsif move == "Assasinate"
			g.update_attributes(:assas => true)
		elsif move == "Steal"
			g.update_attributes(:cap => true)
		end

		if (t != "")&&(g.coup||g.assas||g.cap)
			g.update_attributes(:target => t)
		end
	end 

	def last_move(g) 
		if g.assas
			return "assasinating "+ g.target
		elsif g.duke
			return "tax"
		elsif g.ambs
			return "exchange"
		elsif g.fa
			return "foreign aid"
		elsif g.coup
			return "couping "+ g.target
		elsif g.cap
			return "stealing from "+ g.target
		elsif g.inc
			return "income"
		elsif g.contessa
			return "blocking with contessa"
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
