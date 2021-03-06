# coding: utf-8

require 'sinatra'
require 'sinatra/reloader'
require 'net/http'
require 'json'
require 'active_record'
require 'yaml'
require 'haml'
require 'pp'
require_relative 'models/result'

ActiveRecord::Base.configurations = YAML.load_file(File.join(__dir__, '../config/database.yml'))
ActiveRecord::Base.establish_connection(settings.environment)

configure :production, :development do
  config = YAML.load_file(File.join(__dir__, '../config/config.yml'))

  set :secret, config['secret']
  set :per_page, 30
  set :haml, :format => :html5
end

configure :development do
  set :server, 'webrick'
end

after do
  ActiveRecord::Base.connection.close
end

get '/' do

  @items = Result.order('date DESC').limit(settings.per_page)
  @total_counts = Result.group('result').count

  if @total_counts['win'].nil?
    @total_win_rate  = 0
    @total_lose_rate  = 100
    @total_counts['win'] = 0
  end
  if @total_counts['lose'].nil?
    @total_win_rate  = 100
    @total_lose_rate  = 0
    @total_counts['lose'] = 0
  end
  if @total_counts['win'] != 0 and @total_counts['lose'] != 0
    @total_win_rate = (@total_counts['win'] / (@total_counts['win'] + @total_counts['lose']).to_f) * 100
    @total_win_rate = @total_win_rate.round(1)
    @total_lose_rate = (100 - @total_win_rate).round(1)
  end

  @week_counts = Result.where('? <= date', (Time.now - 7 * 24 * 60 * 60).strftime('%Y-%m-%d %H:%M:%S')).group('result').count

  if @week_counts['win'].nil?
    @week_win_rate  = 0
    @week_lose_rate  = 100
    @week_counts['win'] = 0
  end
  if @week_counts['lose'].nil?
    @week_win_rate  = 100
    @week_lose_rate  = 0
    @week_counts['lose'] = 0
  end
  if @week_counts['win'] != 0 and @week_counts['lose'] != 0
    @week_win_rate = (@week_counts['win'] / (@week_counts['win'] + @week_counts['lose']).to_f) * 100
    @week_win_rate = @week_win_rate.round(1)
    @week_lose_rate = (100 - @week_win_rate).round(1)
  end

  @today_counts = Result.where('? <= date', (Time.now - 24 * 60 * 60).strftime('%Y-%m-%d %H:%M:%S')).group('result').count

  if @today_counts['win'].nil?
    @today_win_rate  = 0
    @today_lose_rate  = 100
    @today_counts['win'] = 0
  end
  if @today_counts['lose'].nil?
    @today_win_rate  = 100
    @today_lose_rate  = 0
    @today_counts['lose'] = 0
  end
  if @today_counts['win'] != 0 and @today_counts['lose'] != 0
    @today_win_rate = (@today_counts['win'] / (@today_counts['win'] + @today_counts['lose']).to_f) * 100
    @today_win_rate = @today_win_rate.round(1)
    @today_lose_rate = (100 - @today_win_rate).round(1)
  end

  max_continuity_temp = Result.get_max_continuity

  @max_continuity = {
      max_continuity_temp[0]['result'] => max_continuity_temp[0]['continuity_count'].to_s,
      max_continuity_temp[1]['result'] => max_continuity_temp[1]['continuity_count'].to_s
  }

  haml :index
end

get '/page/:page' do
  page = params[:page]

  unless valid_page?(page)
    status(400)
    return { :result => false, :msg => '無効なページ指定です' }.to_json
  end

  page = params[:page].to_i
  items = Result.order('date DESC').offset(settings.per_page * (page - 1)).limit(settings.per_page)

  rendered_items = []
  items.each do |item|
    rendered_items.push(haml(:result, :locals => { :item => item }))
  end

  { :result => true, :items => rendered_items }.to_json
end

get '/image/:id' do

  unless Result.exists?(params[:id])
    status(400)
    return { :result => false, :msg => '対象のレコードは存在しません' }.to_json
  end

  result = Result.find(params[:id])

  content_type('application/octet-stream')
  result.image
end

post '/upload' do

  if settings.secret != params['secret']
    status(403)
    return { :result => false, :msg => '認証に失敗しました' }.to_json
  end

  result = Result.new
  result.result = params['result']
  result.date   = params['datetime']
  result.image  = params['image'][:tempfile].read

  unless result.save
    status(400)
    return { :result => false }.to_json
  end

  { :result => true }.to_json
end

def valid_page?(page)
  return false if page.nil?
  return false unless page =~ /^[0-9]+$/
  return false if page.to_i <= 0
  true
end
