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

set :port, ENV['PORT']

get '/charge-point-list' do
  response = static_ochp_client.call(:get_charge_point_list)
  content_type 'application/json'
  json(
    response.body[:get_charge_point_list_response][:charge_point_info_array].ensure_array.map do |charge_point|
      {
        evseId: charge_point[:evse_id],
        locationId: charge_point[:location_id],
        timestamp: charge_point.dig(:timestamp, :date_time),
        locationName: charge_point[:location_name],
        locationNameLang: charge_point[:location_name_lang],
        images: Parser.one_or_multiple(charge_point[:images], Parser.method(:evse_image_url)),
        relatedResources: Parser.one_or_multiple(charge_point[:related_resources], Parser.method(:related_resource)),
        address: Parser.address(charge_point[:charge_point_address]),
        location: Parser.geo_point(charge_point[:location]),
        locationType: charge_point.dig(:location, :general_location_type),
        relatedLocations: Parser.one_or_multiple(charge_point[:related_location], Parser.method(:additional_geo_point)),
        timezone: charge_point[:time_zone],
        openingTimes: Parser.hours(charge_point[:opening_times]),
        status: if charge_point.dig(:status, :charge_point_status_type)
                  charge_point[:status][:charge_point_status_type].downcase
                end,
        statusSchedule: Parser.one_or_multiple(charge_point[:status_schedule], Parser.method(:charge_point_schedule)),
        telephoneNumber: charge_point[:telephone_number],
        parkingSpots: Parser.one_or_multiple(charge_point[:parking_spot], Parser.method(:parking_spot_info)),
        restrictions: Parser.one_or_multiple(charge_point[:restriction], Parser.method(:restriction)),
        authMethods: Parser.one_or_multiple(charge_point[:auth_method], Parser.method(:auth_method)),
        connectors: Parser.one_or_multiple(charge_point[:connectors], Parser.method(:connector)),
        chargePointType: charge_point[:charge_point_type],
        ratings: Parser.ratings(charge_point[:ratings]),
        userInterfaceLang: Parser.one_or_multiple(
          charge_point[:user_interface_lang],
          Parser.method(:user_interface_lang)
        ),
        maxReservation: charge_point.key(:max_reservation) ? charge_point[:max_reservation].to_f : nil
      }
    end
  )
end

get '/live/status' do
  response = live_ochp_client.call(:get_status)
  content_type 'application/json'
  json(
    response.body[:get_status_response][:evse].ensure_array.map do |status|
      {
        evseId: status[:evse_id],
        major: status[:@major],
        minor: status[:@minor],
        ttl: status[:@ttl]
      }
    end
  )
end
