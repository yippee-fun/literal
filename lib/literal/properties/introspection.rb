# frozen_string_literal: true

module Literal::Properties::Introspection
	def positional_properties
		literal_properties.filter(&:positional?)
	end

	def keyword_properties
		literal_properties.filter(&:keyword?)
	end

	def required_properties
		literal_properties.filter(&:required?)
	end

	def required_positional_properties
		required_properties.filter(&:positional?)
	end

	def required_keyword_properties
		required_properties.filter(&:keyword?)
	end

	def optional_positional_properties
		positional_properties - required_positional_properties
	end

	def optional_keyword_properties
		keyword_properties - required_keyword_properties
	end

	def positional_property_names
		positional_properties.map(&:name)
	end

	def keyword_property_names
		keyword_properties.map(&:name)
	end

	def required_property_names
		required_properties.map(&:name)
	end

	def required_positional_property_names
		required_positional_properties.map(&:name)
	end

	def required_keyword_property_names
		required_keyword_properties.map(&:name)
	end

	def optional_positional_property_names
		optional_positional_properties.map(&:name)
	end

	def optional_keyword_property_names
		optional_keyword_properties.map(&:name)
	end

	def property_descriptions
		literal_properties.each_with_object({}) do |prop, hash|
			hash[prop.name] = prop.description
		end
	end

	def described_properties
		literal_properties.filter(&:description?)
	end

	def described_property_names
		described_properties.map(&:name)
	end
end
