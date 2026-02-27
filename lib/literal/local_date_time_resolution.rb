# frozen_string_literal: true

class Literal::LocalDateTimeResolution < Literal::Data
	Disambiguation = _Union(:earlier, :later, :reject, :compatible)

	prop :local_date_time, Literal::LocalDateTime
	prop :time_zone, _Deferred { Literal::TimeZone }
	prop :instants, _Array(Literal::Instant)
	prop :gap, _Boolean, default: false

	#: () -> bool
	def missing?
		@gap
	end

	#: () -> bool
	def ambiguous?
		@instants.length > 1
	end

	#: () -> bool
	def resolved?
		@gap == false && @instants.length == 1
	end

	#: () -> Array[Literal::ZonedDateTime]
	def candidates
		@instants.map { |instant| @time_zone.to_zoned_date_time(instant) }
	end

	#: (disambiguation: Disambiguation) -> Literal::ZonedDateTime
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
