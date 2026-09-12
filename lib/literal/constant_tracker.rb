# frozen_string_literal: true

require "weakref"

module Literal::ConstantTracker
	CONST_GET_METHOD = Module.instance_method(:const_get)
	CONSTANTS = ObjectSpace::WeakKeyMap.new
	EMPTY_REFERENCES = [].freeze

	# A strong owner would keep its constant value alive through this map's
	# values, defeating the weak key when the owner is unloaded.
	Reference = Data.define(:owner_ref, :const) do
		def owner
			owner_ref.__getobj__
		rescue WeakRef::RefError
			nil
		end

		def current?(object)
			owner = self.owner
			owner && !owner.autoload?(const, false) && owner.const_defined?(const, false) &&
				CONST_GET_METHOD.bind_call(owner, const, false).equal?(object)
		rescue NameError
			false
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

	def self.const_ref(object)
		references = CONSTANTS[object]
		return EMPTY_REFERENCES unless references

		references.select! { |reference| reference.current?(object) }
		references.empty? ? EMPTY_REFERENCES : references
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

		return super if object in Literal::Immediate

		begin
			references = Literal::ConstantTracker.const_ref(object).reject do |reference|
				reference.owner.equal?(self) && reference.const == const
			end
			CONSTANTS[object] = references << Reference.new(WeakRef.new(self), const)
		rescue
			# object is not weak-keyable or hashable.
			return super
		end

		super
	end
end
