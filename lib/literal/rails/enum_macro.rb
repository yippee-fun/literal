# frozen_string_literal: true

module Literal::Rails::EnumMacro
	def literal_enum(name, enum, **)
		attribute(name, **)

		decorate_attributes([name]) do |_name, subtype|
			if subtype == ActiveModel::Type.default_value
				raise Literal::ArgumentError.new(<<~MESSAGE.squish)
					Undeclared attribute type for literal_enum #{name.inspect} in #{self.name}.
					Back it with a database column or declare its type with `attribute`.
				MESSAGE
			end

			subtype = subtype.subtype if Literal::Rails::EnumType === subtype
			Literal::Rails::EnumType.new(enum, subtype)
		end
	end
end
