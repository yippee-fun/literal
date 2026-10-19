# frozen_string_literal: true

include Literal::Types

# Only CRuby has Ractors.
if RUBY_ENGINE == "ruby"
	class RactorStruct < Literal::Struct
		prop :position, _Tuple(Integer, Integer)
		prop :tags, _Array(String), default: -> { [] }
		prop :label, String, &:to_s
		prop :next, _Nilable(_Deferred { RactorStruct })
	end

	class RactorData < Literal::Data
		prop :name, _String(size: 1..)
		prop :point, _Map(x: Integer, y: Integer)
	end

	class RactorObject < Literal::Object
		prop :count, Integer, :positional, reader: :public
	end

	class RactorRange < Literal::Struct
		prop :min, Integer
		prop :max, Integer

		checks do |errors, min:, max:|
			errors.add(:min, "must not be greater than max") if min > max
		end
	end

	module RactorTypes
		extend Literal::Types

		# Frozen before the constant it names exists.
		Later = Ractor.make_shareable(_Deferred { Pair })
		Pair = _Tuple(String, Integer)

		Itself = Ractor.make_shareable(_Deferred { Itself.materialize })
	end

	[RactorStruct, RactorData, RactorObject, RactorRange].each do |shape|
		Ractor.make_shareable(shape.literal_properties)
	end

	Ractor.make_shareable(RactorRange.literal_checks)

	# Ruby 3.3 cannot autoload outside the main Ractor.
	Literal::Checks::Collector

	class Quickdraw::Test
		def in_ractor(&)
			experimental, Warning[:experimental] = Warning[:experimental], false
			ractor = Ractor.new(&)
			ractor.respond_to?(:value) ? ractor.value : ractor.take
		ensure
			Warning[:experimental] = experimental
		end
	end

	test "shapes are built and read inside a Ractor once their properties are shareable" do
		assert Ractor.shareable?(RactorStruct.literal_properties)

		struct, data, object = in_ractor do
			[
				RactorStruct.new(position: [1, 2], label: :head, next: RactorStruct.new(position: [3, 4], label: "tail")),
				RactorData.new(name: "origin", point: { x: 0, y: 0 }),
				RactorObject.new(3),
			]
		end

		assert_equal struct.position, [1, 2]
		assert_equal struct.label, "head"
		assert_equal struct.next.label, "tail"
		assert_equal struct.next.tags, []
		assert_equal data, RactorData.new(name: "origin", point: { x: 0, y: 0 })
		assert_equal object.count, 3
	end

	test "type errors are raised inside a Ractor" do
		raised = in_ractor do
			RactorStruct.new(position: [1, "2"], label: "head")
		rescue Literal::TypeError => error
			error.class
		end

		assert_equal raised, Literal::TypeError
	end

	test "a struct can still be changed inside a Ractor" do
		label = in_ractor do
			struct = RactorStruct.new(position: [1, 2], label: "head")
			struct.label = "renamed"
			struct.label
		end

		assert_equal label, "renamed"
	end

	test "a deferred type frozen before first use still matches inside a Ractor" do
		matches = in_ractor { [RactorTypes::Later === ["a", 1], RactorTypes::Later === [1, "a"]] }

		assert_equal matches, [true, false]
	end

	test "checks run inside a Ractor once they are shareable" do
		outcome = in_ractor do
			range = RactorRange.new(min: 1, max: 2)
			failures = []

			begin
				RactorRange.new(min: 3, max: 2)
			rescue Literal::CheckError => error
				failures << error.message
			end

			begin
				range.min = 5
			rescue Literal::CheckError => error
				failures << error.message
			end

			[range.min, failures]
		end

		assert_equal outcome, [1, ["Unsound #{RactorRange}\n  min must not be greater than max\n"] * 2]
	end

	test "a frozen deferred type that resolves to itself does not recurse forever" do
		assert_same RactorTypes::Itself.materialize, RactorTypes::Itself
	end

	test "the types with nested types are shareable as built" do
		assert Ractor.shareable?(_Tuple(String, Integer))
		assert Ractor.shareable?(_Map(name: String))
		assert Ractor.shareable?(_String(size: 1..))
		assert Ractor.shareable?(_Intersection(String, _Interface(:upcase)))
	end

	test "properties cannot be added once they are shareable" do
		error = assert_raises(Literal::ArgumentError) do
			RactorObject.prop :extra, Integer
		end

		assert_equal error.message, "Cannot define :extra on #{RactorObject}, because its properties are frozen."
	end
end
