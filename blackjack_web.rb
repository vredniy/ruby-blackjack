require 'sinatra'
require './blackjack'

enable :sessions

helpers do
  def save_game(g)
    session[:game] = Marshal.dump(g)
  end

  def game
    unless session[:game]
      save_game(Game.new)
    end

    Marshal.load(session[:game])
  end

  def make_move(player_id, move)
    g = game
    g.make_move(params[:player_id], move)
    save_game(g)
  end
end

get '/' do
  erb :mainpage
end

get '/:player_id/:move' do
  make_move(params[:player_id], params[:move])

  redirect '/'
end

get '/new_game' do
  session[:game] = nil

  redirect '/'
end

post '/make_bet' do
  g = game
  g.make_bet(params[:bet].to_i)
  save_game(g)

  redirect '/'
end
