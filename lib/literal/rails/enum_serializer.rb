# frozen_string_literal: true

class Literal::Rails::EnumSerializer < ActiveJob::Serializers::ObjectSerializer
	def serialize?(object)
		Literal::Enum === object
	end

	def serialize(object)
		super(
			"class" => object.class.name,
			# The value goes through ActiveJob so values that aren’t JSON primitives (e.g. symbols) survive the round trip.
			"value" => ActiveJob::Arguments.serialize([object.value]).first
		)
	end

	def deserialize(hash)
		enum = hash["class"].constantize

		unless Class === enum && enum < Literal::Enum
			raise ArgumentError.new("#{hash['class']} is not a Literal::Enum")
		end

		enum.fetch(ActiveJob::Arguments.deserialize([hash["value"]]).first)
	end

	def klass
		Literal::Enum
	end
end
