# frozen_string_literal: true

class Literal::PlainDateTimeResolution < Literal::Data
	Disambiguation = _Union(:earlier, :later, :reject, :compatible)

	prop :plain_date_time, Literal::PlainDateTime
	prop :time_zone, _Deferred { Literal::TimeZone }
	prop :instants, _Array(Literal::Instant)
	prop :gap, _Boolean, default: false

	def missing?
		@gap
	end

	def ambiguous?
		@instants.length > 1
	end

	def resolved?
		@gap == false && @instants.length == 1
	end

	def candidates
		@instants.map { |instant| @time_zone.to_zoned_date_time(instant) }
	end

	def disambiguate(disambiguation: :compatible)
		raise ArgumentError unless Disambiguation === disambiguation

		if missing?
			raise ArgumentError
		end

		instant = if @instants.length == 1
			@instants[0]
		else
			case disambiguation
			in :earlier
				@instants.min
			in :later
				@instants.max
			in :reject
				raise ArgumentError
			in :compatible
				@instants.min
			end
		end

		@time_zone.to_zoned_date_time(instant)
	end
end
