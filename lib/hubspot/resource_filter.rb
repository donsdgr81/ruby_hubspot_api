# frozen_string_literal: true

module Hubspot
  module ResourceFilter
    module FilterGroupMethods
      # Simplified search interface
      OPERATOR_MAP = {
        '_contains' => 'CONTAINS_TOKEN',
        '_gt' => 'GT',
        '_lt' => 'LT',
        '_gte' => 'GTE',
        '_lte' => 'LTE',
        '_neq' => 'NEQ',
        '_in' => 'IN',
        '_between' => 'BETWEEN',
        '_not_has_property' => 'NOT_HAS_PROPERTY',
        '_has_property' => 'HAS_PROPERTY'
      }.freeze

      # Convert simple filters to HubSpot's filterGroups format
      def build_filter_groups(filters)
        if filters.is_a?(Array)
          filters.map { |filter_hash| { filters: build_filters(filter_hash) } }
        else
          [{ filters: build_filters(filters) }]
        end
      end

      def build_filters(filters)
        filters.map do |key, value|
          filter = extract_property_and_operator(key, value)

          if filter[:operator] == 'BETWEEN'
            filter[:value] = value[0]
            filter[:highValue] = value[1]
          elsif %w[HAS_PROPERTY NOT_HAS_PROPERTY].include?(filter[:operator])
            # Do not add value
          else
            value_key = value.is_a?(Array) ? :values : :value
            filter[value_key] = value unless value.blank?
          end
          filter
        end
      end

      # Extract property name and operator from the key
      def extract_property_and_operator(key, value)
        return { propertyName: key.to_s, operator: 'NOT_HAS_PROPERTY' } if value.blank?

        OPERATOR_MAP.each do |suffix, hubspot_operator|
          if key.to_s.end_with?(suffix)
            return {
              propertyName: key.to_s.sub(suffix, ''),
              operator: hubspot_operator
            }
          end
        end

        # Default to 'EQ' operator if no suffix is found
        { propertyName: key.to_s, operator: 'EQ' }
      end
    end
  end
end
