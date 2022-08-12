# frozen_string_literal: true

require 'dotenv'
require 'sinatra'
require 'sinatra/json'
require 'savon'
require 'json'
require 'date'
require 'base64'
require_relative './parser'

Dotenv.load("#{__dir__}/../.env")

# rubocop:disable Style/SingleLineMethods,Style/Documentation
# Extend Object / Array / NilClass by "ensure_array" which turns the object into an array if it is not already one
class Object; def ensure_array; [self] end end
class Array; def ensure_array; to_a end end
class NilClass; def ensure_array; to_a end end
# rubocop:enable Style/SingleLineMethods,Style/Documentation

def global_savon_config(config)
  config.wsdl("#{__dir__}/../ochp-1.4/ochp.wsdl")
  config.wsse_auth(ENV['OCHP_USERNAME'], ENV['OCHP_PASSWORD'])
  config
end

def direct_savon_config(config, wsse: true)
  config.wsdl("#{__dir__}/../ochp-1.3/ochp-direct.wsdl")
  config.wsse_auth(ENV['OCHP_USERNAME'], ENV['OCHP_PASSWORD']) if wsse
  config.convert_request_keys_to(:none)
end

static_ochp_client = Savon.client do |config|
  global_savon_config(config)
  config.endpoint(ENV['OCHP_SERVICE_ENDPOINT'])
end

live_ochp_client = Savon.client do |config|
  global_savon_config(config)
  config.endpoint(ENV['OCHP_LIVE_ENDPOINT'])
end

direct_chs_ochp_client = Savon.client do |config|
  direct_savon_config(config)
  config.endpoint(ENV['OCHP_DIRECT_ENDPOINT'])
end

def direct_cpo_ochp_client(endpoint, basic_auth)
  Savon.client do |config|
    direct_savon_config(config, wsse: false)
    config.endpoint(endpoint)
    config.basic_auth(basic_auth['username'], basic_auth['password'])
  end
end

def get_basic_auth(env)
  # Get basic auth from the request to use it for the request to the CPO
  basic_auth = env['HTTP_AUTHORIZATION']
  if !env.key?('HTTP_AUTHORIZATION') || basic_auth.nil? || basic_auth.empty?
    content_type 'application/json'
    halt 401, json({ error: 'missing_auth' })
  end
  basic_auth = Base64.decode64(env['HTTP_AUTHORIZATION'].split(' ')[1])
  { 'username' => basic_auth.split(':')[0], 'password' => basic_auth.split(':')[1] }
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

post '/endpoints' do
  body = JSON.parse(request.body.read)
  d = DateTime.now.new_offset(0) + 1 # tomorrow UTC
  d = d.strftime('%Y-%m-%dT%H:%M:%SZ')
  direct_chs_ochp_client.call(:add_service_endpoints, message: { providerEndpointArray: [{
                                url: ENV['OCHP_SOAP_MOCK_SERVER'],
                                namespaceUrl: 'http://ochp.eu/1.3',
                                accessToken: body['accessToken'],
                                validUntil: { DateTime: body['validUntil'].nil? ? d : body['validUntil'] },
                                whitelist: ["#{ENV['OCHP_EMP_ID']}C%"]
                              }] })
  halt 204
end

get '/endpoints' do
  response = direct_chs_ochp_client.call(:get_service_endpoints)
  content_type 'application/json'
  json Parser.one_or_multiple(
    response.body[:get_service_endpoints_response][:operator_endpoint_array],
    Parser.method(:operator_endpoint)
  )
end

post '/session' do
  body = JSON.parse(request.body.read)
  client = direct_cpo_ochp_client(body['endpoint'], get_basic_auth(env))
  response = client.call(:select_evse, message: {
                           evseId: body['evseId'],
                           contractId: "#{ENV['OCHP_EMP_ID']}C#{body['contractId']}"
                         })
  content_type 'application/json'
  json Parser.evse_selection(response.body[:select_evse_response])
end

post '/session/:directId/start' do
  body = JSON.parse(request.body.read)
  client = direct_cpo_ochp_client(body['endpoint'], get_basic_auth(env))
  client.call(:control_evse, message: {
                directId: params['directId'],
                operation: { operation: 'start' }
              })
  halt 204
end

delete '/session/:directId' do
  body = JSON.parse(request.body.read)
  client = direct_cpo_ochp_client(body['endpoint'], get_basic_auth(env))
  client.call(:control_evse, message: {
                directId: params['directId'],
                operation: { operation: 'end' }
              })
  client.call(:release_evse, message: {
                directId: params['directId']
              })
  halt 204
end
