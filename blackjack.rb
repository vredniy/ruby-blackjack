class Card
  # diamonds hearts clubs spades
  SUIT_ARRAY = %w(D H C S)
  RANK_ARRAY = (2..10).to_a + %w(J Q K A)

  def initialize(value)
    @rank = value % 13
    @suit = value / 13
    @opened = true
  end

  def close!
    @opened = false
    self
  end

  def weight
    case @rank
    when 0..8
      @rank + 2
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
    "#{RANK_ARRAY[@rank]}#{SUIT_ARRAY[@suit]}"
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
      @cards.pop
    else
      @cards.pop.close!
    end || raise(Exception, 'Not enough cards')
  end
end

class Player
  attr_accessor :bust, :hand
  attr_reader :playable, :current_bet

  def initialize
    @bust = false
    @playable = true
    @hand = Hand.new
  end

  def hand_value
    hand.value
  end

  def take_card(game)
    begin
      @hand.push game.deck.get_one
      check_value
    rescue Exception
      # no cards left
    end
  end

  def check_value
    if hand_value > 21
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
  end
end

class HumanPlayer < Player
  def split_hand(game)
    new_human_player = HumanPlayer.new
    old_human_player = game.human_players[0]
    new_human_player.make_bet old_human_player.current_bet

    game.human_players.push new_human_player
    new_human_player.hand.cards = [old_human_player.hand.cards.pop]
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
    if hand_value < 17
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
  attr_accessor :deck, :human_players, :dealer_player

  attr_reader :human_money
  attr_reader :finished
  attr_reader :result

  def initialize
    @human_money = 1000
    @finished = false
    @deck = Deck.new
  end

  def make_bet(bet)
    rerun_the_game

    initialize_players

    @human_players[0].make_bet(bet)

    deal_the_cards
  end

  def make_move(player_index, move_string)
    current_player = @human_players[player_index.to_i]
    current_player.make_move!(move_string, self)

    check_state
  end

  def end_session
    @finished = true

    return check_all_human_players_busted_result if all_human_players_busted?
    return check_dealer_player_busted_resut if dealer_player_busted?

    _, human2 = sort_humans_by_hand_values

    if human2
      three_players_result
    else
      two_players_result
    end
  end

  private

  def rerun_the_game
    @finished = false
  end

  def initialize_players
    @human_players = [HumanPlayer.new]
    @dealer_player = DealerPlayer.new
  end

  def deal_the_cards
    2.times { @human_players[0].hand.cards.push deck.get_one }

    # one card isn't opened
    @dealer_player.hand.cards.push deck.get_one(false)
    @dealer_player.hand.cards.push deck.get_one
  end

  def check_state
    if all_human_players_busted?
      # dealer win, no need to take card for him
      return @result = end_session
    end

    if no_human_players_playable_left?
      return dealer_turn
    end
  end

  def dealer_turn
    if any_human_players_not_busted?
      while @dealer_player.take_card(self); end
    end

    @result = end_session
  end

  def all_human_players_busted?
    all_human_players_busted.size == @human_players.size
  end

  # there is no playable human on this game
  def no_human_players_playable_left?
    @human_players.all? { |p| !p.playable? }
  end

  def any_human_players_not_busted?
    !all_human_players_not_busted.size.zero?
  end

  def any_human_players_busted?
    !all_human_players_busted.size.zero?
  end

  def dealer_player_busted?
    @dealer_player.bust
  end

  def all_human_players_not_busted
    @human_players.select { |p| !p.bust }
  end

  def all_human_players_busted
    @human_players.select { |p| p.bust }
  end

  # first element contains human_player that has greater or equal hand_value
  def sort_humans_by_hand_values
    human1, human2 = @human_players
    ret_array = [human1, human2]

    # did split?
    if human2
      if human1.hand_value < human2.hand_value
        ret_array = [human2, human1]
      end
    end

    ret_array
  end

  def check_result_for_at_least_one_human_busted
    not_busted_hand_value = all_human_players_not_busted[0].hand_value
    busted_hand_value = all_human_players_busted[0].hand_value
    dealer_hand_value = @dealer_player.hand_value

    if not_busted_hand_value > dealer_hand_value
      @human_money += not_busted_hand_value
      @human_money -= busted_hand_value

      'Human won'
    else
      @human_money -= all_human_players_not_busted[0].current_bet
      @human_money -= all_human_players_busted[0].current_bet

      'Dealer won'
    end
  end

  def check_result_for_two_not_busted_humans
    human1, human2 = sort_humans_by_hand_values
    human1_hand_value, human2_hand_value = [human1, human2].map(&:hand_value)
    dealer_hand_value = @dealer_player.hand_value

    if human1_hand_value > dealer_hand_value
      # at least on human won
      if human2_hand_value > dealer_hand_value
        # two humans won
        @human_money += human1.current_bet + human2.current_bet

        '2 Humans won'
      else
        # human2 loose
        @human_money -= human2.current_bet
        @human_money += human1.current_bet

        '1 Human won'
      end
    else
      # 2 humans loose
      @human_money -= all_human_players_not_busted.map(&:current_bet).reduce :+

      'Dealer won'
    end
  end

  def three_players_result
    if any_human_players_busted?
      # at least one of the humans busted
      check_result_for_at_least_one_human_busted
    else
      check_result_for_two_not_busted_humans
    end
  end

  def two_players_result
    human = all_human_players_not_busted[0]
    human_hand_value, dealer_hand_value = [human, @dealer_player].map(&:hand_value)

    if human_hand_value > dealer_hand_value
      @human_money += human.current_bet

      'Human won'
    else
      @human_money -= human.current_bet

      'Dealer won'
    end
  end

  def check_all_human_players_busted_result
    all_human_players_busted.each do |human_player|
      @human_money -= human_player.current_bet
    end

    'Dealer won'
  end

  def check_dealer_player_busted_resut
    all_human_players_not_busted.each do |human_player|
      @human_money += human_player.current_bet
    end

    'Human won'
  end
end
