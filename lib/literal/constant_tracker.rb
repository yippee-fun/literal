# frozen_string_literal: true

module Literal::ConstantTracker
	CONSTANTS = ObjectSpace::WeakKeyMap.new

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

	def const_added(const)
		return super if autoload?(const, false)

		begin
			object = const_get(const, false)
		rescue ::NameError
			return super
		end

		begin
			(CONSTANTS[object] ||= []) << Reference.new(self, const)
		rescue ::ArgumentError
			return super
			# object is not weak-keyable: integer, symbol, true, false, nil, etc.
		end

		super
	end
end
