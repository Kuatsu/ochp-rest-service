# frozen_string_literal: true

require 'dotenv'
require 'sinatra'
require 'sinatra/json'
require 'savon'
require_relative './parser'

Dotenv.load("#{__dir__}/../.env")

# rubocop:disable Style/SingleLineMethods,Style/Documentation
# Extend Object / Array / NilClass by "ensure_array" which turns the object into an array if it is not already one
class Object; def ensure_array; [self] end end
class Array; def ensure_array; to_a end end
class NilClass; def ensure_array; to_a end end
# rubocop:enable Style/SingleLineMethods,Style/Documentation

def global_savon_config(config)
  wsdl_content = File.read("#{__dir__}/../ochp-1.4/ochp.wsdl")
  config.wsdl(wsdl_content)
  config.wsse_auth(ENV['OCHP_USERNAME'], ENV['OCHP_PASSWORD'])
  config
end

static_ochp_client = Savon.client do |config|
  global_savon_config(config)
  config.endpoint(ENV['OCHP_SERVICE_ENDPOINT'])
end

live_ochp_client = Savon.client do |config|
  global_savon_config(config)
  config.endpoint(ENV['OCHP_LIVE_ENDPOINT'])
end

set :bind, '0.0.0.0'
set :port, ENV['PORT']

get '/charge-point-list' do
  response = static_ochp_client.call(:get_charge_point_list)
  content_type 'application/json'
  json Parser.one_or_multiple(
    response.body[:get_charge_point_list_response][:charge_point_info_array],
    Parser.method(:charge_point_info)
  )
end

get '/live/status' do
  response = live_ochp_client.call(:get_status)
  content_type 'application/json'
  json Parser.one_or_multiple(
    response.body[:get_status_response][:evse],
    Parser.method(:live_status)
  )
end
