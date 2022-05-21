# frozen_string_literal: true

# Contains commonly used methods to parse the SOAP data from the OCHP protocol
module Parser
  def self.one_or_multiple(hash, parser)
    return [] if hash.nil?

    hash.ensure_array.map do |obj|
      parser.call(obj)
    end
  end

  def self.exceptional_period(exceptional_period)
    {
      periodBegin: exceptional_period[:period_begin],
      periodEnd: exceptional_period[:period_end]
    }
  end

  def self.evse_image_url(evse_image_url)
    {
      uri: evse_image_url[:uri],
      thumbUri: evse_image_url[:thumb_uri],
      class: evse_image_url[:class],
      type: evse_image_url[:type],
      width: evse_image_url.key?(:width) ? evse_image_url[:width].to_i : nil,
      height: evse_image_url.key?(:height) ? evse_image_url[:height].to_i : nil
    }
  end

  def self.related_resource(related_resource)
    {
      uri: related_resource[:uri],
      class: related_resource[:class].ensure_array
    }
  end

  def self.geo_point(geo_point)
    {
      latitude: geo_point[:@lat],
      longitude: geo_point[:@lon]
    }
  end

  def self.additional_geo_point(additional_geo_point)
    {
      latitude: additional_geo_point[:@lat],
      longitude: additional_geo_point[:@lon],
      name: additional_geo_point[:@name],
      type: additional_geo_point[:@type]
    }
  end

  def self.regular_hours(regular_hours)
    {
      weekday: regular_hours[:@weekday].to_i,
      periodBegin: regular_hours[:@period_begin],
      periodEnd: regular_hours[:@period_end]
    }
  end

  def self.hours(hours)
    return [] if hours.nil?

    {
      regularHours: one_or_multiple(hours[:regular_hours], method(:regular_hours)),
      twentyfourseven: hours[:twentyfourseven] == 'true',
      closedCharging: hours[:closed_charging] == 'true',
      exceptionalOpenings: one_or_multiple(hours[:exceptional_openings], method(:exceptional_period)),
      exceptionalClosings: one_or_multiple(hours[:exceptional_closings], method(:exceptional_period))
    }
  end

  def self.address(address)
    {
      street: address[:address],
      city: address[:city],
      zipCode: address[:zip_code],
      country: address[:country],
      houseNumber: address[:house_number]
    }
  end

  def self.charge_point_schedule(charge_point_schedule)
    {
      startDate: charge_point_schedule[:start_date],
      endDate: charge_point_schedule[:end_date],
      status: charge_point_schedule[:status]
    }
  end

  def self.connector(connector)
    {
      connectorStandard: connector[:connector_standard][:connector_standard],
      connectorFormat: connector[:connector_format][:connector_format].downcase,
      tariffId: connector[:tariff_id]
    }
  end

  def self.ratings(ratings)
    return nil if ratings.nil?

    {
      maximumPower: ratings[:maximum_power].to_i,
      guaranteedPower: ratings.key?(:guaranteed_power) ? ratings[:guaranteed_power].to_i : nil,
      nominalVoltage: ratings.key?(:nominal_voltage) ? ratings[:nominal_voltage].to_i : nil
    }
  end

  def self.restriction(restriction)
    restriction[:restriction_type]
  end

  def self.auth_method(auth_method)
    auth_method[:auth_method_type]
  end

  def self.user_interface_lang(user_interface_lang)
    user_interface_lang
  end

  def self.parking_spot_info(parking_spot_info)
    {
      parkingId: parking_spot_info[:parking_id],
      restrictions: one_or_multiple(parking_spot_info[:restriction], method(:restriction)),
      floorLevel: parking_spot_info[:floorlevel],
      parkingSpotNumber: parking_spot_info[:parking_spot_number]
    }
  end
end
