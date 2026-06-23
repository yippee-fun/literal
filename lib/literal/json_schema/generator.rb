# frozen_string_literal: true

module Literal
	module JsonSchema
		# Generates JSON Schema from Literal types and structures
		class Generator
			class << self
				def generate(type)
					if type.is_a?(Class) && type < Literal::DataStructure
						generate_data_structure(type)
					else
						TypeMapper.map_type(type)
					end
				end

				private

				def generate_data_structure(type)
					schema = {}
					type.literal_properties.each do |prop|
						schema[prop.name] = generate(prop.type)
						schema[prop.name][:nullable] = true if prop.optional?
					end

					required = type.literal_properties.select(&:required?).reject(&:default?).map(&:name).map(&:to_s)
					{
						type: "object",
						properties: schema,
						required:,
						additionalProperties: false,
					}
				end
			end
		end
	end
end
