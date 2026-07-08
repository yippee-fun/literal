# frozen_string_literal: true

module Literal::ConstantTracker
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
	rescue ::StandardError
		EMPTY_REFERENCES
	end

	def self.immediate_value?(object)
		object in Integer | Float | Symbol | nil | true | false
	end

	def const_added(const)
		return super if autoload?(const, false)

		begin
			object = const_get(const, false)
		rescue ::NameError
			return super
		end

		return super if Literal::ConstantTracker.immediate_value?(object)

		begin
			(CONSTANTS[object] ||= []) << Reference.new(self, const)
		rescue ::StandardError
			# object is not weak-keyable or hashable.
			return super
		end

		super
	end
end
