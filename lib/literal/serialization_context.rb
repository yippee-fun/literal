# frozen_string_literal: true

class Literal::SerializationContext
	include Literal::Types

	DefaultSerializers = [
		Literal::NeverSerializer,
		Literal::VoidSerializer,
		Literal::StringSerializer,
		Literal::SymbolSerializer,
		Literal::IntegerSerializer,
		Literal::JSONSchemaNumberSerializer,
		Literal::FloatSerializer,
		Literal::BooleanSerializer,
		Literal::TimeSerializer,
		Literal::DateSerializer,
		Literal::StructureSerializer,
		Literal::TaggedUnionSerializer,
		Literal::UnionSerializer,
		Literal::HashSerializer,
		Literal::EnumSerializer,
		Literal::MapSerializer,
		Literal::TupleSerializer,
		Literal::ArraySerializer,
		Literal::SetSerializer,
		Literal::ArrayCollectionSerializer,
		Literal::SetCollectionSerializer,
		Literal::HashCollectionSerializer,
		Literal::TupleCollectionSerializer,
		Literal::RangeSerializer,
		Literal::NilableSerializer,
		Literal::JSONDataSerializer,
	].freeze

	# Bound for the fallback type caches on engines without a weak-keyed map.
	# Types can be constructed ad hoc, so an unbounded cache would grow with
	# every fresh type object; when a fallback cache fills up it is simply
	# cleared, and long-lived types repopulate it immediately.
	CacheLimit = 2048

	def initialize(*serializers, defaults: true)
		serializers = [*serializers, *DefaultSerializers] if defaults

		@type = _Deferred { @type }
		@kind = _Deferred { @kind }

		@serializers = serializers.map { |it| it.new(self) }.freeze

		@type = Literal::Serializer::SerializableType.new(self, _Union(*@serializers.map(&:type)))
		@kind = _Kind(@type)

		@cache_mutex = Mutex.new
		@serializer_cache = new_type_cache
		@serializable_cache = new_type_cache
		@object_shape_cache = new_type_cache

		freeze
	end

	attr_reader :serializers
	attr_reader :type
	attr_reader :kind

	def json_schema(type)
		Literal::JSONSchema::Generator.new(self).generate(type)
	end

	def serialize(value, type:, strict: true)
		type = type.materialize if type in Literal::Types::DeferredType

		if aggregate_type?(type)
			serializer, type = serializer_for_value(value)
		else
			serializer = serializer_for_type(type)
		end

		if strict && !(type === value)
			raise Literal::ArgumentError, "Value #{value.inspect} cannot be serialized as #{type.inspect}"
		end

		serialized = serializer.serialize(value, type:)

		if strict && !(_JSONData? === serialized)
			raise Literal::ArgumentError, "Value #{value.inspect} was not serialized correctly"
		end

		serialized
	end

	def deserialize(value, type:, strict: true)
		type = type.materialize if type in Literal::Types::DeferredType

		serializer = serializer_for_type(type)
		value = serializer.coerce(value)

		if strict && !(_JSONData === value)
			raise Literal::ArgumentError, "Value #{value.inspect} is not valid JSON data and cannot be deserialized as #{type.inspect}"
		end

		deserialized = serializer.deserialize(value, type:)

		if strict && !(type === deserialized)
			raise Literal::ArgumentError, "Value #{value.inspect} cannot be deserialized as #{type.inspect}"
		end

		deserialized
	end

	# The serializer handling the given type. With after, the search resumes
	# from the serializer following it in the chain, giving a custom serializer
	# super-like access to the serializer it shadowed.
	def serializer_for_type(type, after: nil)
		serializer = if after
			serializer_matching_type_after(type, after)
		else
			serializer_matching_type(type)
		end

		return serializer if serializer

		if after
			raise Literal::ArgumentError, "No serializer for type #{type.inspect} after #{after.class}"
		else
			raise Literal::ArgumentError, "No serializer for type #{type.inspect}"
		end
	end

	# Whether this context can round-trip values of the given type. This is the
	# only place that recurses through a type's children: serializers answer
	# the shallow questions (handles_type?, child_types, referenceable?) and this
	# walk owns cycle detection. A cycle is legal if it passes back through a
	# referenceable type, since values of such types are still finite and the
	# JSON Schema generator can express the cycle as a "$ref".
	def serializable_type?(type)
		type = type.materialize if type in Literal::Types::DeferredType

		cached = @serializable_cache[type]
		return cached unless cached.nil?

		result = serializable_type_within?(type, {}.compare_by_identity, @serializable_cache)
		cache_store(@serializable_cache, type, false) unless result
		result
	end

	# Builds a descriptive error for a type that failed serializable_type?, by
	# re-walking the type to find a path to the failure. This is only called on
	# the error path, so it doesn't need to be fast.
	def unserializable_type_error(type)
		path = unserializable_type_path(type, {}.compare_by_identity)

		unless path
			return Literal::ArgumentError.new("No serializer for type #{type.inspect}")
		end

		failed = path.last

		reason = if serializer_matching_type(failed)
			"it recurses through #{failed.inspect}, which cannot be referenced from a JSON Schema"
		elsif (rejection = rejection_reason(failed))
			(path.length == 1) ? rejection : "there is no serializer for #{failed.inspect}: #{rejection}"
		elsif path.length == 1
			"no serializer matches it"
		else
			"there is no serializer for #{failed.inspect}"
		end

		trail = (path.length > 1) ? " (#{path.map(&:inspect).join(' → ')})" : ""

		Literal::ArgumentError.new("Type #{type.inspect} cannot be serialized because #{reason}#{trail}.")
	end

	# Whether any serializer in this context matches the type, without the
	# recursive serializability walk.
	def serializer_for?(type)
		type = type.materialize if type in Literal::Types::DeferredType

		!serializer_matching_type(type).nil?
	end

	def referenceable_type?(type)
		type = type.materialize if type in Literal::Types::DeferredType

		serializer = serializer_matching_type(type)
		serializer ? serializer.referenceable?(type) : false
	end

	def json_type(type)
		type = type.materialize if type in Literal::Types::DeferredType

		serializer_matching_type(type)&.json_type(type)
	end

	# Cached, unlike json_type: building a shape allocates and serializes
	# constant values, and union member dispatch consults shapes per value.
	def object_shape(type)
		type = type.materialize if type in Literal::Types::DeferredType

		cached = @object_shape_cache[type]

		if cached.nil?
			cached = serializer_matching_type(type)&.object_shape(type) || false
			cache_store(@object_shape_cache, type, cached)
		end

		cached || nil
	end

	def build_json_schema(type, generator:)
		serializer_for_type(type).json_schema(type, generator:)
	end

	private def serializable_type_within?(type, stack, seen)
		type = type.materialize if type in Literal::Types::DeferredType

		# Only this context's own aggregate type is trivially serializable;
		# another context's aggregate proves nothing about this one.
		return type.equal?(@type) if Literal::Serializer::SerializableType === type
		return referenceable_type?(type) if stack.key?(type)

		cached = seen[type]
		return cached unless cached.nil?

		serializer = serializer_matching_type(type)
		return false unless serializer

		stack[type] = true
		result = serializer.child_types(type).all? { |child| serializable_type_within?(child, stack, seen) }
		stack.delete(type)

		# Only positive results are safe to remember from mid-walk: a negative
		# may depend on the current stack, but success never does.
		cache_store(seen, type, true) if result
		result
	end

	private def unserializable_type_path(type, stack)
		type = type.materialize if type in Literal::Types::DeferredType

		if Literal::Serializer::SerializableType === type
			return type.equal?(@type) ? nil : [type]
		end

		if stack.key?(type)
			return referenceable_type?(type) ? nil : [type]
		end

		serializer = serializer_matching_type(type)
		return [type] unless serializer

		stack[type] = true

		begin
			serializer.child_types(type).each do |child|
				if (failure = unserializable_type_path(child, stack))
					return [type, *failure]
				end
			end
		ensure
			stack.delete(type)
		end

		nil
	end

	private def rejection_reason(type)
		@serializers.each do |serializer|
			if (reason = serializer.rejection_reason(type))
				return reason
			end
		end

		nil
	end

	# Uncached, unlike serializer_matching_type: super calls are rare and the
	# chain is short, so a second cache dimension isn't worth carrying.
	private def serializer_matching_type_after(type, after)
		serializers = @serializers
		index = serializers.index(after)

		unless index
			raise Literal::ArgumentError, "#{after.class} is not one of this context's serializers"
		end

		i, length = index + 1, serializers.length

		while i < length
			serializer = serializers[i]
			return serializer if serializer.handles_type?(type)
			i += 1
		end

		nil
	end

	private def serializer_matching_type(type)
		cached = @serializer_cache[type]

		if cached.nil?
			cached = @serializers.find { |it| it.handles_type?(type) } || false
			cache_store(@serializer_cache, type, cached)
		end

		cached || nil
	end

	# Weakly keyed where the engine supports it, so ad-hoc types can be
	# garbage collected; otherwise a bounded hash cleared when full.
	private def new_type_cache
		if defined?(ObjectSpace::WeakKeyMap)
			ObjectSpace::WeakKeyMap.new
		else
			{}.compare_by_identity
		end
	end

	private def cache_store(cache, key, value)
		@cache_mutex.synchronize do
			cache.clear if Hash === cache && cache.size >= CacheLimit
			cache[key] = value
		end

		value
	rescue ArgumentError
		# Immediate values (nil, true, 42, :sym) cannot be weak map keys.
		# They're cheap to re-dispatch, so they are simply not cached.
		value
	end

	private def serializer_for_value(value)
		@serializers.each do |serializer|
			if (type = serializer.value_type(value))
				return [serializer, type]
			end
		end

		raise Literal::ArgumentError, "Value #{value.inspect} cannot be serialized as #{@type.inspect}"
	end

	private def aggregate_type?(type)
		Literal::Serializer::SerializableType === type
	end
end
