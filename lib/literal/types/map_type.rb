# frozen_string_literal: true

# @api private
class Literal::Types::MapType
	include Literal::Type

	def initialize(shape)
		@required = {}
		@optional = {}
		@forbidden = Set[]

		shape.each do |key, type|
			if Literal::Types::NeverType === type
				@forbidden.add(key)
			elsif type === nil
				@optional[key] = type
			else
				@required[key] = type
			end
		end

		@shape = shape.freeze
		@required.freeze
		@optional.freeze
		@forbidden.freeze

		freeze
	end

	attr_reader :shape

	def inspect
		"_Map(#{@shape.inspect})"
	end

	def ===(other)
		return false unless Hash === other
		return false if other.size < @required.size

		if other.size < @shape.size
			required_matches = 0

			other.each do |key, actual|
				if @required.key?(key)
					return false unless @required[key] === actual
					required_matches += 1
				elsif @optional.include?(key)
					return false unless @optional[key] === actual
				elsif @forbidden.include?(key)
					return false
				end
			end

			required_matches == @required.size
		else
			@shape.each do |key, expected|
				next if @forbidden.include?(key) && !other.key?(key)
				next if @optional.include?(key) && !other.key?(key)

				return false unless expected === other[key]
			end

			true
		end
	end

	def record_literal_type_errors(context)
		unless Hash === context.actual
			return
		end

		@shape.each do |key, expected|
			unless context.actual.key?(key)
				next if @optional.include?(key) || @forbidden.include?(key)

				context.add_child(label: "[#{key.inspect}]", expected:, actual: nil)
				next
			end

			actual = context.actual[key]
			if @forbidden.include?(key)
				context.add_child(label: "[#{key.inspect}]", expected:, actual:)
				next
			end

			unless expected === actual
				context.add_child(label: "[#{key.inspect}]", expected:, actual:)
			end
		end
	end

	def >=(other, context: nil)
		case other
		when Literal::Types::MapType
			other_shape = other.shape

			@shape.all? do |k, v|
				Literal.subtype?(other_shape.fetch(k, nil), v, context:)
			end
		else
			false
		end
	end
end
