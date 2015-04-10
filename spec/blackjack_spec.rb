require 'spec_helper'

require './blackjack'

describe 'Card' do
  describe '#opened?' do
    context 'default is true' do
      subject { Card.new(1) }

      it { expect(subject.opened?).to be true }
    end

    context 'false when opened set to false' do
      subject { Card.new(50).close! }

      it { expect(subject.opened?).to be false }
    end
  end

  describe '#to_s' do
    subject { Card.new(@value).to_s }

    context '2 of Diamonds' do
      before { @value = 0 }

      it { expect(subject).to eq '2D' }
    end

    context '10 of Hearts' do
      before { @value = 21 }

      it { expect(subject).to eq '10H' }
    end

    context 'Ace of Clubs' do
      before { @value = 38 }

      it { expect(subject).to eq 'AC' }
    end

    context 'Queen of Spades' do
      before { @value = 49 }

      it { expect(subject).to eq 'QS' }
    end
  end

  describe '#weight' do
    subject { Card.new(@value).weight }

    context '2 of Diamonds' do
      before { @value = 0 }

      it { expect(subject).to eq 2 }
    end

    context '10 of Hearts' do
      before { @value = 21 }

      it { expect(subject).to eq 10 }
    end

    context 'Ace of Clubs' do
      before { @value = 38 }

      it { expect(subject).to eq 11 }
    end

    context 'Queen of Spades' do
      before { @value = 49 }

      it { expect(subject).to eq 10 }
    end
  end
end

describe 'Hand' do
  describe 'initialization' do
    subject { Hand.new }
    it 'should be empty array' do
      expect(subject.cards).to eq []
    end
  end

  describe '#push' do
    subject { @hand.cards.map &:to_s }
    before { @hand = Hand.new }

    context '2 cards' do
      before do
        @hand.push Card.new(38) # Ace of Clubs
        @hand.push Card.new(21) # 10 of Hearts
      end

      it { expect(subject).to eq %w(AC 10H) }
    end
  end

  describe '#value' do
    subject { @hand.value }

    before { @hand = Hand.new }

    context 'for no cards' do
      it { expect(subject).to eq 0 }
    end

    context 'for some cards' do
      before do
        @hand.push Card.new(20) # 9 hearts
        @hand.push Card.new(4) # 6 diamonds
        @hand.push Card.new(50) # KING spades
      end

      it { expect(subject).to eq 25 }
    end
  end
end

describe 'Deck' do
  describe 'initialization' do
    subject { Deck.new }

    it { expect(subject.cards.size).to eq 52 }

    # 2, 2, 2, 2, 3, 3, 3, 3 ... 11
    it { expect(subject.cards.map(&:weight).sort.inject(:+)).to eq 380 }
  end

  describe '#get_one' do
    context 'just card' do
      subject { Deck.new.get_one }

      it { expect(subject).to be_an_instance_of Card }
      it { expect(subject.opened?).to be true }
    end

    context 'closed' do
      subject { Deck.new.get_one(false) }

      it { expect(subject).to be_an_instance_of Card }
      it { expect(subject.opened?).to be false }
    end

    context '52 times' do
      subject { @deck.cards }

      before do
        @deck = Deck.new
        52.times { @deck.get_one }
      end

      it { expect(subject).to eq [] }
      it do
        expect { @deck.get_one }.to raise_error(Exception, 'Not enough cards')
      end
    end
  end
end

describe Player do
  describe 'initialization' do
    subject { Player.new }

    it { expect(subject.bust).to be false }
    it { expect(subject.playable).to be true }
    it { expect(subject.hand).to be_an_instance_of Hand }
  end

  describe '#check_value' do
    subject { @player.check_value }

    context '> 21' do
      before do
        hand_double = double('hand')
        allow(Hand).to receive(:new).and_return hand_double
        expect(hand_double).to receive(:value) { 22 }

        @player = Player.new

        subject
      end

      it { expect(@player.bust).to be true }
      it { expect(@player.playable).to be false }
    end

    context '<= 21' do
      before do
        hand_double = double('hand')
        allow(Hand).to receive(:new).and_return hand_double
        expect(hand_double).to receive(:value) { 21 }

        @player = Player.new

        subject
      end

      it { expect(@player.bust).to be false }
      it { expect(@player.playable).to be true }
    end
  end

  describe HumanPlayer do
    it { expect(subject).to be_a_kind_of Player }

    describe '#make_bet' do
      subject { @human_player.current_bet }

      before { @human_player = HumanPlayer.new }
      before { @human_player.make_bet 42 }

      it { expect(subject).to eq 42 }
    end
  end

  describe DealerPlayer do
    it { expect(subject).to be_a_kind_of Player }
  end
end

describe Game do
  describe 'initialization' do
    subject { Game.new }
    
    it { expect(subject.human_money).to eq 1000 }
    it { expect(subject.finished).to eq false }
    it { expect(Deck).to receive(:new).and_call_original; subject }
  end

  describe '#make_bet' do
    subject { @game.make_bet 100 }

    before { @game = Game.new }

    it { expect(HumanPlayer).to receive(:new).and_call_original; subject }
    it { expect(DealerPlayer).to receive(:new).and_call_original; subject }

    it { subject; expect(@game.human_players[0].hand.cards.size).to eq 2 }
    # one card is not opened
    it { subject; expect(@game.dealer_player.hand.cards.map &:opened?).to eq [false, true] }
  end

  describe '#end_session' do
    context 'splitted' do
      context 'dealer won (1 human busted)' do
        it do
          game = Game.new
          game.make_bet(250)

          game.human_players[0].hand.cards = [Card.new(0), Card.new(13)]

          expect(game.human_players[0].hand.cards.map &:to_s).to eq %w(2D 2H)

          game.dealer_player.hand.cards = [Card.new(8), Card.new(9)]

          game.human_players[0].split_hand(game)

          expect(game.human_players.size).to eq 2
          expect(game.human_players[0].hand.cards[0].to_s).to eq '2D'
          expect(game.human_players[1].hand.cards[0].to_s).to eq '2H'

          game.human_players[1].hand.cards = [Card.new(12), Card.new(25)]
          game.human_players[1].check_value

          expect(game.end_session).to match /Dealer won/

          expect(game.human_money).to eq 500
        end
      end

      context 'dealer won' do
        it do
          game = Game.new
          game.make_bet(250)

          game.human_players[0].hand.cards = [Card.new(0), Card.new(13)]

          expect(game.human_players[0].hand.cards.map &:to_s).to eq %w(2D 2H)

          game.dealer_player.hand.cards = [Card.new(8), Card.new(9)]

          game.human_players[0].split_hand(game)

          expect(game.human_players.size).to eq 2
          expect(game.human_players[0].hand.cards[0].to_s).to eq '2D'
          expect(game.human_players[1].hand.cards[0].to_s).to eq '2H'

          expect(game.end_session).to match /Dealer won/

          expect(game.human_money).to eq 500
        end
      end

      context '1 human 1 lose' do
        it do
          game = Game.new
          game.make_bet(250)

          game.human_players[0].hand.cards = [Card.new(1), Card.new(25)]

          game.dealer_player.hand.cards = [Card.new(2), Card.new(3).close!]

          game.human_players[0].split_hand(game)

          expect(game.human_players.size).to eq 2

          expect(game.end_session).to match /1 Human won/

          expect(game.human_money).to eq 1000
        end
      end

      context '2 humans wins (1 doubled)' do
        it do
          game = Game.new
          game.make_bet(250)

          game.human_players[0].hand.cards = [Card.new(12), Card.new(25)]

          game.dealer_player.hand.cards = [Card.new(2), Card.new(3).close!]

          game.human_players[0].split_hand(game)
          game.human_players[1].double_bet(game)

          expect(game.human_players.size).to eq 2

          expect(game.end_session).to match /2 Humans won/

          expect(game.human_money).to eq 1750
        end
      end
    end

    context 'not splitted' do
      context 'dealer busted' do
        it do
          game = Game.new
          game.make_bet(100)
          game.dealer_player.bust = true

          expect(game.end_session).to match /Human won/

          expect(game.finished).to eq true
          expect(game.human_money).to eq 1100
        end
      end

      context 'human busted' do
        it do
          game = Game.new
          game.make_bet(500)
          game.human_players[0].bust = true

          expect(game.end_session).to match /Dealer won/

          expect(game.finished).to eq true
          expect(game.human_money).to eq 500
        end
      end

      context 'nobody busted' do
        it do
          game = Game.new
          game.make_bet(30)

          game.human_players[0].hand.cards = [Card.new(0), Card.new(1), Card.new(2)]
          game.dealer_player.hand.cards = [Card.new(8), Card.new(9)]

          expect(game.end_session).to match /Dealer won/

          expect(game.finished).to eq true
          expect(game.human_money).to eq 970
        end
      end
    end
  end
end

