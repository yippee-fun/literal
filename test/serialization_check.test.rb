# frozen_string_literal: true

class SerializationCheckTest < Quickdraw::Test
	Context = Literal::SerializationContext.new

	class Address < Literal::Data
		prop :city, String
		prop :since, Date
	end

	class Booking < Literal::Data
		prop :guest, String
		prop :date, Date
		prop :address, _Nilable(Address), default: nil
		prop :dates, _Array(Date), default: -> { [] }
		prop? :note, String

		check(:guest, "must not be blank") { |guest:| !guest.empty? }
	end

	class Coerced < Literal::Data
		prop :date, Date do |value|
			Date.parse(value)
		end
	end

	class Sealed < Literal::Data
		prop :code, _String(length: 1), &(Literal::Seal { |it| it.strip.freeze })
	end

	class Counted < Literal::Data
		prop :name, String
	end

	class Tally < Literal::Data
		prop :entry, _Union(Counted, _Map(count: Integer))
	end

	class Unserializable < Literal::Data
		prop :callback, Proc
	end

	def errors_for(result)
		result.error!.errors.map { |error| [error.path, error.message] }
	end

	test "decodes serialized values and builds the shape" do
		body = { "guest" => "Ada", "date" => "2026-01-02" }
		booking = Context.check(body, type: Booking).value!

		assert_equal Date.new(2026, 1, 2), booking.date
		assert_equal Context.deserialize(body, type: Booking), booking
	end

	test "reports a value that cannot be decoded instead of raising" do
		result = Context.check({ "guest" => "Ada", "date" => "soon" }, type: Booking)

		assert_equal [[[:date], "must be a date"]], errors_for(result)
	end

	test "reports unknown keys and missing props" do
		result = Context.check({ "date" => "2026-01-02", "extra" => 1 }, type: Booking)

		assert_equal [[[:extra], "is not a known field"], [[:guest], "is missing"]], errors_for(result)
	end

	test "runs checks against the decoded values" do
		result = Context.check({ "guest" => "", "date" => "2026-01-02" }, type: Booking)

		assert_equal [[[:guest], "must not be blank"]], errors_for(result)
	end

	test "decodes a nested shape prop by prop" do
		result = Context.check(
			{ "guest" => "Ada", "date" => "2026-01-02", "address" => { "city" => 1, "since" => "later" } },
			type: Booking
		)

		assert_equal [[[:address, :city], "must be a string"], [[:address, :since], "must be a date"]], errors_for(result)
	end

	test "builds a nested shape from decoded values" do
		booking = Context.check(
			{ "guest" => "Ada", "date" => "2026-01-02", "address" => { "city" => "Paris", "since" => "2020-05-01" } },
			type: Booking
		).value!

		assert_equal Address.new(city: "Paris", since: Date.new(2020, 5, 1)), booking.address
	end

	test "reports a collection that cannot be decoded against its prop" do
		result = Context.check({ "guest" => "Ada", "date" => "2026-01-02", "dates" => ["2026-01-02", "never"] }, type: Booking)

		assert_equal [[[:dates], "must be an array where each member is a date"]], errors_for(result)
	end

	test "leaves an omitted optional prop undefined" do
		booking = Context.check({ "guest" => "Ada", "date" => "2026-01-02" }, type: Booking).value!

		assert_equal Literal::Undefined, booking.note
	end

	test "decodes a present optional prop" do
		booking = Context.check({ "guest" => "Ada", "date" => "2026-01-02", "note" => "window seat" }, type: Booking).value!

		assert_equal "window seat", booking.note
	end

	test "decodes a coerced prop without re-running the coercion" do
		assert_equal Date.new(2025, 1, 13), Context.check({ "date" => "2025-01-13" }, type: Coerced).value!.date
	end

	test "seals a decoded value before checking its type" do
		assert_equal "a", Context.check({ "code" => " a " }, type: Sealed).value!.code
	end

	test "decodes an object whole when another union member could mean it" do
		assert_equal({ count: 3 }, Context.check({ "entry" => { "count" => 3 } }, type: Tally).value!.entry)
	end

	test "reports a payload that is not an object" do
		result = Context.check([], type: Booking)

		assert_equal [[[], "must be an object"]], errors_for(result)
	end

	test "raises for a type the context cannot serialize" do
		assert_raises(Literal::ArgumentError) { Context.check({}, type: Unserializable) }
	end
end
