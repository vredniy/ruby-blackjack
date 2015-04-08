require 'sinatra'
require './blackjack'

enable :sessions

helpers do
  def save_game(g)
    session[:game] = Marshal.dump(g)
  end

  def game
    if session[:game]
      Marshal.load(session[:game])
    else
      g = Game.new
      session[:game] = Marshal.dump(g)
      g
    end
  end
end

get '/:player_id/stay' do
  g = game
  g.make_move(params[:player_id], 'stay')
  save_game(g)

  redirect '/'
end


get '/:player_id/double_bet' do
  g = game
  g.make_move(params[:player_id], 'double_bet')
  save_game(g)

  redirect '/'
end


get '/:player_id/take_card' do
  g = game
  g.make_move(params[:player_id], 'take_card')
  save_game(g)

  redirect '/'
end

get '/:player_id/split_hand' do
  g = game
  g.make_move(params[:player_id], 'split_hand')
  save_game(g)

  redirect '/'
end

get '/' do
  erb :mainpage
end

get '/new_game' do
  session[:game] = nil

  redirect '/'
end

post '/make_bet' do
  g = game

  bet = params[:bet].to_i

  g.make_bet(bet)
  # g.make_move(0, 'make_bet', bet)

  save_game(g)

  redirect '/'
end
