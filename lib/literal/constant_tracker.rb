# frozen_string_literal: true

require "weakref"

module Literal::ConstantTracker
	CONST_GET_METHOD = Module.instance_method(:const_get)
	CONSTANTS = ObjectSpace::WeakMap.new
	LISTS = {}.compare_by_identity
	LISTS_MUTEX = Mutex.new
	MINIMUM_LISTS_LIMIT = 1024
	EMPTY_REFERENCES = [].freeze
	@lists_limit = MINIMUM_LISTS_LIMIT

	# A strong owner would keep its constant value alive through this map's
	# values, defeating the weak key when the owner is unloaded.
	Reference = Data.define(:owner_ref, :const) do
		def owner
			owner_ref.__getobj__
		rescue WeakRef::RefError
			nil
		end

		# The constant's value, or nil when it no longer resolves.
		def value
			owner = self.owner

			if owner && !owner.autoload?(const, false) && owner.const_defined?(const, false)
				CONST_GET_METHOD.bind_call(owner, const, false)
			end
		rescue NameError
			nil
		end

		def current?(object)
			value.equal?(object)
		end

		def name
			owner = self.owner
			return unless owner

			if owner == Object
				const.to_s
			elsif owner.name
				"#{owner.name}::#{const}"
			else
				"#<anonymous #{owner.class}>::#{const}"
			end
		end

		def to_s
			name.to_s
		end
	end

	# Objects are tracked by identity, so equal objects held by different
	# constants keep their own references, and collecting one leaves the
	# other's. A WeakMap holds its values weakly too, so the reference lists
	# are held in LISTS, which is pruned of collected objects' lists as it
	# grows.
	def self.track(object, references)
		LISTS_MUTEX.synchronize do
			previous = CONSTANTS[object]
			LISTS.delete(previous) if previous
			CONSTANTS[object] = references
			LISTS[references] = true

			if LISTS.size > @lists_limit
				# Gathered before LISTS lets go, or a collection part way through
				# would take lists not yet reached.
				live = {}.compare_by_identity
				CONSTANTS.each_value { |list| live[list] = true }
				LISTS.replace(live)
				@lists_limit = [LISTS.size * 2, MINIMUM_LISTS_LIMIT].max
			end
		end
	end

	def self.const_ref(object)
		references = CONSTANTS[object]
		return EMPTY_REFERENCES unless references

		current = references.select { |reference| reference.current?(object) }
		current.empty? ? EMPTY_REFERENCES : current
	rescue
		EMPTY_REFERENCES
	end

	def const_added(const)
		return super if autoload?(const, false)

		begin
			object = CONST_GET_METHOD.bind_call(self, const, false)
		rescue ::NameError
			return super
		end

		return super if Literal::Immediate === object

		references = Literal::ConstantTracker.const_ref(object).reject do |reference|
			reference.owner.equal?(self) && reference.const == const
		end
		Literal::ConstantTracker.track(object, [*references, Reference.new(WeakRef.new(self), const)])

		super
	end
end
