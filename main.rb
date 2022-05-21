require 'dotenv/load'
require 'sinatra'
require 'sinatra/json'
require 'savon'

class Object; def ensure_array; [self] end end
class Array; def ensure_array; to_a end end
class NilClass; def ensure_array; to_a end end

static_ochp_client = Savon.client do |config|
  wsdl_content = File.read("./ochp-1.4/ochp.wsdl")
  config.wsdl(wsdl_content)
  config.wsse_auth(ENV['OCHP_USERNAME'], ENV['OCHP_PASSWORD'])
  config.endpoint(ENV['OCHP_SERVICE_ENDPOINT'])
end

live_ochp_client = Savon.client do |config|
  wsdl_content = File.read("./ochp-1.4/ochp.wsdl")
  config.wsdl(wsdl_content)
  config.wsse_auth(ENV['OCHP_USERNAME'], ENV['OCHP_PASSWORD'])
  config.endpoint(ENV['OCHP_LIVE_ENDPOINT'])
end

set :port, ENV['PORT']

get '/charge-point-list' do
  response = static_ochp_client.call(:get_charge_point_list)
  content_type 'application/json'
  json (
    response.body[:get_charge_point_list_response][:charge_point_info_array].ensure_array.map do |charge_point|
      {
        evseId: charge_point[:evse_id],
        locationId: charge_point[:location_id],
        timestamp: charge_point.dig(:timestamp, :date_time),
        locationName: charge_point[:location_name],
        locationNameLang: charge_point[:location_name_lang],
        images: charge_point.key?(:images) ? charge_point[:images].ensure_array.map do |image|
          {
            uri: image[:uri],
            thumbUri: image[:thumb_uri],
            class: image[:class],
            type: image[:type],
            width: image.key?(:width) ? image[:width].to_i : nil,
            height: image.key?(:height) ? image[:height].to_i : nil,
          }
        end : [],
        relatedResources: charge_point.key?(:related_resource) ? charge_point[:related_resource].ensure_array.map do |related_resource|
          {
            uri: related_resource[:uri],
            class: related_resource[:class].ensure_array
          }
        end : [],
        address: {
          street: charge_point[:charge_point_address][:address],
          city: charge_point[:charge_point_address][:city],
          zipCode: charge_point[:charge_point_address][:zip_code],
          country: charge_point[:charge_point_address][:country],
          houseNumber: charge_point[:charge_point_address][:house_number]
        },
        location: {
          latitude: charge_point[:charge_point_location][:@lat],
          longitude: charge_point[:charge_point_location][:@lon]
        },
        locationType: charge_point.dig(:location, :general_location_type),
        relatedLocation: charge_point.key?(:related_location) ? charge_point.key?(:related_location).ensure_array.map do |related_location|
          {
            latitude: related_location[:@lat],
            longitude: related_location[:@lon],
            name: related_location[:@name],
            type: related_location[:@type]
          }
        end : [],
        timezone: charge_point[:time_zone],
        openingTimes: charge_point.key?(:opening_times) ? {
          regularHours: charge_point[:opening_times].key?(:regular_hours) ? charge_point[:opening_times][:regular_hours].ensure_array.map do |regular_hour|
            {
              weekday: regular_hour[:@weekday].to_i,
              periodBegin: regular_hour[:@period_begin],
              periodEnd: regular_hour[:@period_end],
            }
          end : [],
          twentyfourseven: charge_point[:opening_times].key?(:twentyfourseven) ? charge_point[:opening_times].key?(:twentyfourseven) == 'true' : false,
          closedCharging: charge_point[:opening_times][:closed_charging] == 'true',
          exceptionalOpenings: charge_point[:opening_times].key?(:exceptional_openings) ? charge_point[:opening_times][:exceptional_openings].ensure_array.map do |exceptional_opening|
            {
              periodBegin: exceptional_opening[:period_begin],
              periodEnd: exceptional_opening[:period_end],
            }
          end : [],
          exceptionalClosings: charge_point[:opening_times].key?(:exceptional_closings) ? charge_point[:opening_times][:exceptional_closings].ensure_array.map do |exceptional_closing|
            {
              periodBegin: exceptional_closing[:period_begin],
              periodEnd: exceptional_closing[:period_end],
            }
          end : [],
        } : nil,
        status: charge_point.dig(:status, :charge_point_status_type) ? charge_point[:status][:charge_point_status_type].downcase : nil,
        statusSchedule: charge_point.key?(:status_schedule) ? charge_point[:status_schedule].ensure_array.map do |status_schedule|
          {
            startDate: status_schedule[:start_date],
            endDate: status_schedule[:end_date],
            status: status_schedule[:status]
          }
        end : [],
        telephoneNumber: charge_point[:telephone_number],
        parkingSpots: charge_point.key?(:parking_spot) ? charge_point[:parking_spot].ensure_array.map do |parking_spot|
          {
            parkingId: parking_spot[:parking_id],
            restrictions: parking_spot.key?(:restriction) ? parking_spot[:restriction].ensure_array.map do |restriction|
              restriction[:restriction_type]
            end : [],
            floorLevel: parking_spot[:floorlevel],
            parkingSpotNumber: parking_spot[:parking_spot_number],
          }
        end : [],
        restrictions: charge_point.key?(:restriction) ? charge_point[:restriction].ensure_array.map do |restriction|
          restriction[:restriction_type]
        end : [],
        authMethods: charge_point.key?(:auth_methods) ? charge_point[:auth_methods].ensure_array.map do |authMethod|
          authMethod[:auth_method_type]
        end : [],
        connectors: charge_point.key?(:connectors) ? charge_point[:connectors].ensure_array.map do |connector|
          {
            connectorStandard: connector[:connector_standard][:connector_standard],
            connectorFormat: connector[:connector_format][:connector_format].downcase,
            tariffId: connector[:tariff_id]
          }
        end : [],
        chargePointType: charge_point[:charge_point_type],
        ratings: charge_point.key?(:ratings) ? {
          maximumPower: charge_point[:ratings][:maximum_power].to_i,
          guaranteedPower: charge_point[:ratings].key?(:guaranteed_power) ? charge_point[:ratings][:guaranteed_power].to_i : nil,
          nominalVoltage: charge_point[:ratings].key?(:nominal_voltage) ? charge_point[:ratings][:nominal_voltage].to_i : nil
        } : nil,
        userInterfaceLang: charge_point.key?(:user_interface_lang) ? charge_point[:user_interface_lang].ensure_array.map do |user_interface_lang|
          user_interface_lang
        end : [],
        maxReservation: charge_point.key(:max_reservation) ? charge_point[:max_reservation].to_f : nil
      }
    end
  )
end

get '/live/status' do
  response = live_ochp_client.call(:get_status)
  content_type 'application/json'
  json (
    response.body[:get_status_response][:evse].ensure_array.map do |status|
      {
        evseId: status[:evse_id],
        major: status[:@major],
        minor: status[:@minor],
        ttl: status[:@ttl],
      }
    end
  )
end
