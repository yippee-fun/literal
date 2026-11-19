# frozen_string_literal: true

# @api private
module Literal::Freezing
	extend self

	# A frozen version of a loaded value, for types that require frozen values.
	# Plain data (strings, arrays, hashes and sets) is frozen all the way down,
	# copying anything not already frozen, so the raw input it may share is
	# never mutated. Any other object is shallow_frozen, and left as it is when
	# nested in plain data.
	def deep_frozen(value)
		case value
		in String | Array | Hash | Set
			frozen_data(value, {}.compare_by_identity)
		else
			shallow_frozen(value)
		end
	end

	# A type's member as the type holds it: plain data frozen all the way down,
	# copying anything not already frozen, so mutating what the type was built
	# from can't change what it matches or its hash. Any other object is left
	# as it is.
	#
	# `when`, not `in`: JRuby's pattern matching calls the value's to_s, which a
	# BasicObject lacks and a large array answers by inspecting every element.
	def frozen_member(value)
		case value
		when String, Array, Hash, Set
			frozen_data(value, {}.compare_by_identity)
		else
			value
		end
	end

	# The object, frozen by its own #freeze, which may be private or return
	# something else. A shape's own #freeze may be a reader. One already frozen
	# is left alone, since its #freeze may not expect to run again.
	def shallow_frozen(value)
		return value if Literal::FROZEN.bind_call(value)

		if Literal::Properties === Literal::CLASS.bind_call(value) || !Literal.implements?(value, :freeze)
			Literal::FREEZE.bind_call(value)
		else
			Literal::SEND.bind_call(value, :freeze)
		end

		value
	end

	# Restores the frozen state a type requires throughout a value rebuilt
	# unfrozen, as Marshal.load rebuilds it. Wherever the type requires a
	# frozen value, the value is replaced with its deep_frozen version, just as
	# deserialization would load it. The containers holding those values are
	# updated in place.
	def restore_frozen(value, type)
		restore(value, type, Restoration.new(active: {}.compare_by_identity, restored: {}.compare_by_identity))
	end

	# The values being restored, and each one's replacement by type, all by
	# identity, so a value appearing more than once as a type is replaced by
	# the same object each time, as Marshal shares it.
	Restoration = Data.define(:active, :restored)

	# A value can contain itself, so a value already being restored as a type
	# is left as it is rather than walked again.
	private def restore(value, type, state)
		replacements = (state.restored[value] ||= {}.compare_by_identity)
		return replacements[type] if replacements.key?(type)

		types = (state.active[value] ||= {}.compare_by_identity)
		return value if types.key?(type)

		types[type] = true

		begin
			replacements[type] = restore_as(value, type, state)
		ensure
			types.delete(type)
		end
	end

	private def restore_as(value, type, state)
		case type
		when Literal::Types::DeferredType
			restore(value, type.materialize, state)
		when Literal::Types::FrozenType
			value = restore(value, type.type, state)
			(type.type === value) ? deep_frozen(value) : value
		when Literal::Types::ConstraintType
			value = type.object_constraints.reduce(value) { |item, constraint| restore(item, constraint, state) }

			if Literal.subtype?(type.property_constraints[:frozen?], true) && type.object_constraints.all? { |constraint| constraint === value }
				deep_frozen(value)
			else
				value
			end
		when Literal::Types::UnionType
			restore_member(value, type, type.each, state)
		when Literal::Types::TaggedUnionType
			restore_member(value, type, type.members.each_value, state)
		when Literal::Types::NilableType
			restore(value, type.type, state)
		when Literal::Types::RangeType
			restore_range(value, type, state)
		else
			restore_contents(value, type, state)
			value
		end
	end

	# A value already matching the union needs nothing restored, and trying
	# another member first could freeze what that one requires unfrozen.
	private def restore_member(value, type, members, state)
		return value if type === value

		members.each do |member|
			value = restore(value, member, state)
			break if member === value
		end

		value
	end

	# Ranges are frozen, so one with restored endpoints is a new range.
	private def restore_range(value, type, state)
		return value unless Range === value

		first = restore(value.begin, type.type, state)
		last = restore(value.end, type.type, state)

		if first.equal?(value.begin) && last.equal?(value.end)
			value
		else
			Range.new(first, last, value.exclude_end?)
		end
	end

	private def restore_contents(value, type, state)
		return if Literal::FROZEN.bind_call(value)

		case [type, value]
		in [Literal::Types::ArrayType, Array]
			value.map! { |item| restore(item, type.type, state) }
		in [Literal::Types::SetType, Set]
			value.map! { |item| restore(item, type.type, state) }
		in [Literal::Types::HashType, Hash]
			value.transform_keys! { |key| restore(key, type.key_type, state) }
			value.transform_values! { |item| restore(item, type.value_type, state) }
		in [Literal::Types::MapType, Hash]
			type.shape.each do |key, item_type|
				value[key] = restore(value[key], item_type, state) if value.key?(key)
			end
		in [Literal::Types::TupleType, Array]
			type.types.each_with_index do |item_type, index|
				value[index] = restore(value[index], item_type, state) if index < value.size
			end
		else
			nil
		end
	end

	# Each value is copied once, so a value appearing twice is copied once and a
	# value containing itself is copied containing its copy. Copies are clones,
	# keeping any singleton methods, like a literal's own ===.
	private def frozen_data(value, copies)
		return copies[value] if copies.key?(value)

		case value
		when String
			value.frozen? ? value : (copies[value] = value.clone(freeze: true))
		when Array, Set
			copy = copies[value] = value.clone(freeze: false)
			copy.map! { |item| frozen_data(item, copies) }.freeze
		when Hash
			# A copy keeps the hash's default and key comparison, and so, compared
			# by identity, its keys.
			copy = copies[value] = value.clone(freeze: false).clear
			value.each do |key, item|
				copy[value.compare_by_identity? ? key : frozen_data(key, copies)] = frozen_data(item, copies)
			end
			copy.freeze
		else
			value
		end
	end
end
