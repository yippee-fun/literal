# frozen_string_literal: true

module Literal::ConstantTracker
	CONST_GET_METHOD = Module.instance_method(:const_get)
	CONSTANTS = ObjectSpace::WeakKeyMap.new
	EMPTY_REFERENCES = [].freeze

	Reference = Data.define(:owner, :const) do
		def name
			if owner == Object
				const.to_s
			elsif owner.name
				"#{owner.name}::#{const}"
			else
				"#<anonymous #{owner.class}>::#{const}"
			end
		end

		alias_method :to_s, :name
	end

	def self.const_ref(object)
		CONSTANTS[object] || EMPTY_REFERENCES
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
			(CONSTANTS[object] ||= []) << Reference.new(self, const)
		rescue
			# object is not weak-keyable or hashable.
			return super
		end

		super
	end
end
