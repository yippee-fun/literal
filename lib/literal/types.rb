# frozen_string_literal: true

module Literal::Types
	extend self

	# Matches any value except `nil`. Use `_Any?` or `_Void` to match any value including `nil`.
	# ```ruby
	# _Any
	# ```
	def _Any
		AnyType::Instance
	end

	# Matches any value including `nil`. This is the same as `_Void` and the opposite of `_Never`.
	# ```ruby
	# _Any?
	# ```
	def _Any?
		VoidType::Instance
	end

	# Matches if the value is an `Array` and all the elements of the array match the given type.
	# ```ruby
	# _Array(String)
	# ```
	def _Array(type)
		ArrayType.new(type)
	end

	# Nilable version of `_Array`.
	# ```ruby
	# _Array?(String)
	# ```
	def _Array?(type)
		_Nilable(
			_Array(type)
		)
	end

	# Matches if the value is either `true` or `false`. This is equivalent to `_Union(true, false)`.
	# ```ruby
	# _Boolean
	# ```
	def _Boolean
		BooleanType::Instance
	end

	# Nilable version of `_Boolean`.
	# ```ruby
	# _Boolean?
	# ```
	def _Boolean?
		NilableBooleanType
	end

	# Matches if the value responds to `#call`.
	# ```ruby
	# _Callable
	# ```
	def _Callable
		CallableType
	end

	# Nilable version of `_Callable`.
	# ```ruby
	# _Callable?
	# ```
	def _Callable?
		NilableCallableType
	end

	# Matches if the value either the given class or a subclass of it.
	# ```ruby
	# _Class(ActiveRecord::Base)
	# ```
	def _Class(expected_class)
		ClassType.new(expected_class)
	end

	# Nilable version of `_Class`.
	# ```ruby
	# _Class?(ActiveRecord::Base)
	# ```
	def _Class?(...)
		_Nilable(
			_Class(...)
		)
	end

	# Similar to `_Intersection`, but allows you to specify attribute constraints as keyword arguments.
	# ```ruby
	# _Constraint(Array, size: 1..3)
	# ```
	def _Constraint(*a, **k)
		if a.length == 1 && k.length == 0
			a[0]
		else
			ConstraintType.new(a, k)
		end
	end

	# Nilable version of `_Constraint`
	# ```ruby
	# _Constraint?(Array, size: 1..3)
	# ```
	def _Constraint?(...)
		_Nilable(
			_Constraint(...)
		)
	end

	# Matches if the value is a `Date` and matches the given constraints.
	# If you don't need any constraints, use `Date` instead of `_Date`. See also `_Constraint`.
	# ```ruby
	# _Date((Date.today)..)
	# _Date(year: 2025)
	# ```
	def _Date(...)
		_Constraint(Date, ...)
	end

	# Nilable version of `_Date`.
	def _Date?(...)
		_Nilable(
			_Date(...)
		)
	end

	# Takes a type as a block so it can be resolved when needed. This is useful if declaring your type now would cause an error because constants haven’t been defined yet.
	# ```ruby
	# _Deferred { _Class(SomeFutureConstant) }
	# ```
	def _Deferred(&type)
		DeferredType.new(&type)
	end

	# Nilable version of `_Deferred`.
	def _Deferred?(&type)
		_Nilable(
			_Deferred(&type)
		)
	end

	# Matches if the value is a descendant of the given class.
	# ```ruby
	# _Descendant(ActiveRecord::Base)
	# ```
	def _Descendant(...)
		DescendantType.new(...)
	end

	# Nilable version of `_Descendant`.
	def _Descendant?(...)
		_Nilable(
			_Descendant(...)
		)
	end

	#  Matches if the value is an `Enumerable` and all its elements match the given type.
	# ```ruby
	# _Enumerable(String)
	# ```
	def _Enumerable(type)
		EnumerableType.new(type)
	end

	# Nilable version of `_Enumerable`.
	def _Enumerable?(...)
		_Nilable(
			_Enumerable(...)
		)
	end

	# Matches *"falsy"* values (`nil` and `false`). This is equivalent to `_Nilable(false)` or `_Union(nil, false)`.
	def _Falsy
		FalsyType::Instance
	end

	# Matches if the value is a `Float` and matches the given constraints.
	# You could use a `Range`, for example, as a constraint.
	# If you don't need a constraint, use `Float` instead of `_Float`.
	# ```ruby
	# _Float(5..10)
	# ```
	def _Float(...)
		_Constraint(Float, ...)
	end

	# Nilable version of `_Float`.
	def _Float?(...)
		_Nilable(
			_Float(...)
		)
	end

	# Matches if the value is *frozen*.
	def _Frozen(...)
		FrozenType.new(...)
	end

	# Nilable version of `_Frozen`
	def _Frozen?(...)
		_Nilable(
			_Frozen(...)
		)
	end

	# Matches if the value is a `Hash` and all the keys and values match the given types.
	def _Hash(...)
		HashType.new(...)
	end

	# Nilable version of `_Hash`
	def _Hash?(...)
		_Nilable(
			_Hash(...)
		)
	end

	# Matches if the value is an `Integer` and matches the given constraint.
	# You could use a `Range`, for example, as a constraint.
	# If you don't need a constraint, use `Integer` instead of `_Integer`.
	# @example
	# 	attribute :age, _Integer(18..127)
	def _Integer(...)
		_Constraint(Integer, ...)
	end

	# Nilable version of `_Integer`
	def _Integer?(...)
		_Nilable(
			_Integer(...)
		)
	end

	# Matches if the value responds to all the given methods.
	def _Interface(*methods)
		InterfaceType.new(methods)
	end

	# Nilable version of `_Interface`
	def _Interface?(...)
		_Nilable(
			_Interface(...)
		)
	end

	# Matches if *all* given types are matched.
	def _Intersection(*types)
		IntersectionType.new(types)
	end

	# Nilable version of `_Intersection`
	def _Intersection?(...)
		_Nilable(
			_Intersection(...)
		)
	end

	# Ensures the value is valid JSON data (i.e. it came from JSON.parse).
	def _JSONData(*a, **k)
		if a.length > 0 || k.length > 0
			_Constraint(JSONDataType::Instance, *a, **k)
		else
			JSONDataType::Instance
		end
	end

	# Nilable version of `_JSONData`
	def _JSONData?(...)
		_Nilable(
			_JSONData(...)
		)
	end

	# Matches if the value is a `Proc` and `#lambda?` returns truthy.
	def _Lambda
		LambdaType
	end

	# Nilable version of `_Lambda`
	def _Lambda?
		NilableLambdaType
	end

	# ```ruby
	# _Map(name: String, age: Integer)
	# ```
	def _Map(**shape)
		MapType.new(shape)
	end

	# Nilable version of `_Map`
	# ```ruby
	# _Map?(name: String, age: Integer)
	# ```
	def _Map?(...)
		_Nilable(
			_Map(...)
		)
	end

	# Never matches any value.
	def _Never
		NeverType::Instance
	end

	# Matches if the value is either `nil` or the given type.
	def _Nilable(...)
		NilableType.new(...)
	end

	# Matches if the given type is *not* matched.
	def _Not(*types)
		if types.length > 1
			NotType.new(
				_Union(*types)
			)
		else
			type = types[0]

			case type
			when NotType
				type.type
			else
				NotType.new(type)
			end
		end
	end

	def _Pattern(regex, &block)
		raise ArgumentError.new("Block required for Pattern") unless block

		-> (value) {
			if (data = regex.match(value))
				!!block.call(*data.captures, **data.named_captures&.transform_keys(&:to_sym))
			else
				false
			end
		}
	end

	def _Predicate(message, &block)
		PredicateType.new(message:, block:)
	end

	# Matches if the value is a `Proc` or responds to `#to_proc`.
	def _Procable
		ProcableType
	end

	# Nilable version ofo `_Procable`
	def _Procable?
		NilableProcableType
	end

	# Matches if the value is a `Range` of the given type.
	def _Range(...)
		RangeType.new(...)
	end

	# Nilable version of `_Range`
	def _Range?(...)
		_Nilable(
			_Range(...)
		)
	end

	# Matches if the value is a `Set` and all the elements match the given type.
	def _Set(...)
		SetType.new(...)
	end

	# Nilable version of `_Set`
	def _Set?(...)
		_Nilable(
			_Set(...)
		)
	end

	# Matches if the value is a `String` and matches the given constraints.
	# If you don't need any constraints, use `String` instead of `_String`.
	def _String(...)
		_Constraint(String, ...)
	end

	# Nilable version of `_String`
	def _String?(...)
		_Nilable(
			_String(...)
		)
	end

	# Matches if the value is a `Symbol` and matches the given constraints.
	def _Symbol(...)
		_Constraint(Symbol, ...)
	end

	# Nilable version of `_Symbol`
	def _Symbol?(...)
		_Nilable(
			_Symbol(...)
		)
	end

	# Matches if the value is a `Time` and matches the given constraints.
	# If you don't need any constraints, use `Time` instead of `_Time`.
	def _Time(...)
		_Constraint(Time, ...)
	end

	# Nilable version of `_Time`
	def _Time?(...)
		_Nilable(
			_Time(...)
		)
	end

	# Matches *"truthy"* values (anything except `nil` and `false`).
	def _Truthy
		TruthyType::Instance
	end

	# Matches if the value is an `Array` and each element matches the given types in order.
	# ```ruby
	# _Tuple(String, Integer, Integer)
	# ```
	def _Tuple(*types)
		TupleType.new(types)
	end

	# Nilable version of `_Typle`
	# ```ruby
	# _Tuple?(String, Integer, Integer)
	# ```
	def _Tuple?(...)
		_Nilable(
			_Tuple(...)
		)
	end

	# Matches if the value matches any of the given tagged types. Tags are used to identify which type was matched.
	def _TaggedUnion(**members)
		TaggedUnionType.new(**members)
	end

	# Nilable version of `_TaggedUnion`
	def _TaggedUnion?(...)
		_Nilable(
			_TaggedUnion(...)
		)
	end

	# Matches if *any* given type is matched.
	def _Union(*types)
		UnionType.new(types)
	end

	# Nilable version of `_Union`
	def _Union?(...)
		_Nilable(
			_Union(...)
		)
	end

	# The unit type is a type that matches only the same object
	def _Unit(object)
		UnitType.new(object)
	end

	# Nilable version of `_Unit`
	def _Unit?(...)
		_Nilable(
			_Unit(...)
		)
	end

	def _Void
		VoidType::Instance
	end

	ProcableType = _Interface(:to_proc)
	CallableType = _Interface(:call)
	LambdaType = _Constraint(Proc, lambda?: true)

	NilableBooleanType = _Nilable(BooleanType::Instance)
	NilableCallableType = _Nilable(CallableType)
	NilableJSONDataType = _Nilable(JSONDataType)
	NilableLambdaType = _Nilable(LambdaType)
	NilableProcableType = _Nilable(ProcableType)
end
