class Card
  attr_reader :value

  attr_accessor :suit
  attr_accessor :rank

  def initialize(value, opened=true)
    raise 'Value must be set' unless value

    @rank = value % 13
    @suit = value / 13

    @value = value
    @opened = opened
  end

  def close!
    @opened = false
    self
  end

  def weight
    case rank
    when 0..8
      rank + 2
    when 12
      11
    else
      10
    end
  end

  def opened?
    @opened
  end

  def to_s
    rank_array = (2..10).to_a + %w(J Q K A)
    rank = rank_array[@rank]

    # diamonds hearts clubs spades
    suit_array = %w(D H C S)
    suit = suit_array[@suit]

    "#{rank}#{suit}"
  end
end

class Hand
  attr_accessor :cards

  def initialize
    @cards = []
  end

  def push(card)
    @cards.push card
  end

  def value
    @cards.map(&:weight).inject(:+).to_i # prevents nil value
  end
end

class Deck
  attr_reader :cards

  def initialize
    @cards = (1..52).map { |i| Card.new(i) }
    @cards.shuffle!
  end

  def get_one(opened=true)
    if opened
      @cards.pop || raise('Not enough cards')
    else
      @cards.pop.close!
    end
  end
end

class Player
  attr_accessor :playable, :value, :cards, :current_bet
  attr_accessor :hand
  attr_accessor :bust

  def hand
    if @hand.nil?
      @hand = Hand.new
    end

    @hand
  end

  def initialize
    @bust = false
    @playable = true
    @hand = Hand.new
  end

  def take_card(game)
    if current_card = game.deck.get_one
      @hand.push current_card
    else
      nil
    end

    check_value
  end

  def check_value
    if @hand.value > 21
      @bust = true
      @playable = false
    end
  end

  def playable?
    @playable && !@bust
  end

  def make_move!(move_string, game)
    if respond_to?(move_string.to_sym)
      send(move_string.to_sym, game)
    end
    # split_hand
    # stay
    # double_bet
  end
end

class HumanPlayer < Player
  def split_hand(game)
    new_human_player = self.class.new
    old_human_player = game.human_players[0]
    new_human_player.make_bet old_human_player.current_bet

    game.human_players.push new_human_player
    new_human_player.hand.cards = [old_human_player.hand.cards.pop]

    game
  end

  def stay(game)
    @playable = false
  end

  def make_bet(bet)
    @current_bet = bet
  end

  def double_bet(game)
    @current_bet *= 2
  end
end


class DealerPlayer < Player
  def take_card(game)
    if @hand.value < 17
      if current_card = game.deck.get_one
        @hand.push current_card
      else
        false
      end
    end

    check_value
  end
end

class Game
  attr_accessor :deck, :human_money, :human_players, :dealer_player
  attr_accessor :finished
  attr_accessor :result

  def initialize
    @human_money = 1000
    @finished = false

    @deck = Deck.new
  end

  def make_bet(bet)
    @finished = false

    human_player = HumanPlayer.new
    human_player.make_bet(bet)

    @human_players = [human_player]
    @dealer_player = DealerPlayer.new

    2.times { @human_players[0].hand.cards.push deck.get_one }

    # one card is not opened
    @dealer_player.hand.cards.push deck.get_one(false)
    @dealer_player.hand.cards.push deck.get_one
  end

  def make_move(player_index, move_string)
    current_player = @human_players[player_index.to_i]
    current_player.make_move!(move_string, self)

    check_state
  end


  def check_state
    # all busted
    if @human_players.all? { |p| p.bust }
      # dealer win
      # no need to take card for him
      return end_session
    end

    # there is no playable human on this game
    if @human_players.all? { |p| !p.playable? }
      return dealer_turn
    end
  end

  def dealer_turn
    if @human_players.any? { |p| !p.bust }
      while @dealer_player.take_card(self)
      end
    end

    end_session
  end

  def end_session
    if @dealer_player.bust
      not_busted_players_bets = @human_players.select { |p| !p.bust }.map(&:current_bet).reduce :+
      busted_players_bets = @human_players.select { |p| p.bust }.map(&:current_bet).reduce :+
      @human_money += not_busted_players_bets.to_i - busted_players_bets.to_i
      # counter = @human_players.select { |p| !p.bust }.size
      # @human_money += 2 * @human_players[0].current_bet
      #
      @finished = true
      @result = '1) human won'
      return :human
    end

    if @human_players.all? { |p| p.bust }
      busted_players_bets = @human_players.select { |p| p.bust }.map(&:current_bet).reduce :+

      @human_money -= busted_players_bets.to_i

      @finished = true
      @result = '2) dealer won'
      return :dealer
    end


    # splitted
    if @human_players.size == 2
      if @human_players.all? { |p| !p.bust }
        human1, human2 = @human_players

        human_1_value = human1.hand.value
        human_2_value = human2.hand.value

        dealer_value = @dealer_player.hand.value

        # human_1_value - max human value
        if human_2_value > human_1_value
          human_1_value, human_2_value = [human_2_value, human_1_value]
        end

        if dealer_value >= human_1_value
          @human_money -= human1.current_bet + human2.current_bet
          @finished = true
          @result = '6) dealer won'

          return @result
        end

        if human_1_value > dealer_value
          # at lease one human won
          if human_2_value > dealer_value
            # 2 humans won
            @human_money += human1.current_bet + human2.current_bet
            @finished = true
            @result = '7) 2 humans won'

            return @result
          else
            @finished = true
            @human_money = @human_money + human1.current_bet - human2.current_bet
            @result = '5) 1 human won'

            return @result
          end
        end

        if human_2_value > dealer_value
          # 2 humans won
          @human_money += human1.current_bet + human2.current_bet
          @finished = true
          @result = '8) 2 humans won'

          return @result
        end
      end
    end

    if (not_busted_players = @human_players.select { |p| !p.bust }).any?
      busted_player = @human_players.select { |p| p.bust } 

      not_busted_player = not_busted_players[0]
      max_value = not_busted_players.map { |p| p.hand.value.to_i }.max

      # 1 win and 1 lose
      if not_busted_player.hand.value.to_i > @dealer_player.hand.value
        @human_money += @human_players[0].current_bet

        @finished = true
        @result = '3) human won'
        return :human
      else
        @human_money -= @human_players.map(&:current_bet).inject(:+)

        @finished = true
        @result = '4) dealer won'
        return :dealer
      end
    end
  end
end
