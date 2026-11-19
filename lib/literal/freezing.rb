# frozen_string_literal: true

# @api private
module Literal::Freezing
	extend self

	# A frozen version of a loaded value, for types that require frozen values.
	# Plain data (strings, arrays, hashes and sets) is frozen all the way down,
	# copying anything not already frozen, so the raw input it may share is
	# never mutated. Any other object is frozen by its own #freeze, and left as
	# it is when nested in plain data.
	def deep_frozen(value)
		case value
		when String, Array, Hash, Set
			frozen_data(value)
		else
			value.freeze
		end
	end

	# Restores the frozen state a type requires throughout a value rebuilt
	# unfrozen, as Marshal.load rebuilds it. Wherever the type requires a
	# frozen value, the value is replaced with its deep_frozen version, just as
	# deserialization would load it. The containers holding those values are
	# updated in place.
	def restore_frozen(value, type)
		restore(value, type, {}.compare_by_identity)
	end

	# A value can contain itself, so a value already being restored as a type
	# is left as it is rather than walked again.
	private def restore(value, type, active)
		types = (active[value] ||= {}.compare_by_identity)
		return value if types.key?(type)

		types[type] = true

		begin
			restore_as(value, type, active)
		ensure
			types.delete(type)
		end
	end

	private def restore_as(value, type, active)
		case type
		when Literal::Types::DeferredType
			restore(value, type.materialize, active)
		when Literal::Types::FrozenType
			value = restore(value, type.type, active)
			(type.type === value) ? deep_frozen(value) : value
		when Literal::Types::ConstraintType
			value = type.object_constraints.reduce(value) { |item, constraint| restore(item, constraint, active) }

			if Literal.subtype?(type.property_constraints[:frozen?], true) && type.object_constraints.all? { |constraint| constraint === value }
				deep_frozen(value)
			else
				value
			end
		when Literal::Types::UnionType
			restore_member(value, type, type.each, active)
		when Literal::Types::TaggedUnionType
			restore_member(value, type, type.members.each_value, active)
		when Literal::Types::NilableType
			restore(value, type.type, active)
		when Literal::Types::RangeType
			restore_range(value, type, active)
		else
			restore_contents(value, type, active)
			value
		end
	end

	# A value already matching the union needs nothing restored, and trying
	# another member first could freeze what that one requires unfrozen.
	private def restore_member(value, type, members, active)
		return value if type === value

		members.each do |member|
			value = restore(value, member, active)
			break if member === value
		end

		value
	end

	# Ranges are frozen, so one with restored endpoints is a new range.
	private def restore_range(value, type, active)
		return value unless Range === value

		first = restore(value.begin, type.type, active)
		last = restore(value.end, type.type, active)

		if first.equal?(value.begin) && last.equal?(value.end)
			value
		else
			Range.new(first, last, value.exclude_end?)
		end
	end

	private def restore_contents(value, type, active)
		return if Literal::FROZEN.bind_call(value)

		case [type, value]
		in [Literal::Types::ArrayType, Array]
			value.map! { |item| restore(item, type.type, active) }
		in [Literal::Types::SetType, Set]
			value.map! { |item| restore(item, type.type, active) }
		in [Literal::Types::HashType, Hash]
			value.transform_keys! { |key| restore(key, type.key_type, active) }
			value.transform_values! { |item| restore(item, type.value_type, active) }
		in [Literal::Types::MapType, Hash]
			type.shape.each do |key, item_type|
				value[key] = restore(value[key], item_type, active) if value.key?(key)
			end
		in [Literal::Types::TupleType, Array]
			type.types.each_with_index do |item_type, index|
				value[index] = restore(value[index], item_type, active) if index < value.size
			end
		else
			nil
		end
	end

	# Each container is copied once, so a value containing itself is copied
	# containing its copy.
	private def frozen_data(value, copies = {}.compare_by_identity)
		return copies[value] if copies.key?(value)

		case value
		when String
			value.frozen? ? value : value.dup.freeze
		when Array, Set
			copy = copies[value] = value.dup
			copy.map! { |item| frozen_data(item, copies) }.freeze
		when Hash
			# A copy keeps the hash's default and key comparison.
			copy = copies[value] = value.dup.clear
			value.each { |key, item| copy[frozen_data(key, copies)] = frozen_data(item, copies) }
			copy.freeze
		else
			value
		end
	end
end
