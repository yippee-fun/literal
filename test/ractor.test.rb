# frozen_string_literal: true

class RactorTest < Quickdraw::Test
	include Literal::Types

	# Only CRuby has Ractors, and only from 4.0 can they share the method handles
	# Literal calls through.
	if RUBY_ENGINE == "ruby" && RUBY_VERSION >= "4.0"
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

		class RactorUnshared < Literal::Struct
			prop :name, String
		end

		class RactorBase < Literal::Struct
			prop :id, Integer
		end

		class RactorChild < RactorBase
			prop :name, String
		end

		module RactorPipelines
			extend Literal::Types

			Strip = Literal::Coercion(&:strip)
			Downcase = Literal::Coercion { |value| value.downcase.tr(" ", "-") }
			Immutable = Literal::Seal(&:freeze)
			Codes = Literal::Array(_Pattern(/\A\d+\z/) { true })
		end

		class RactorCoerced < Literal::Struct
			prop :code, _Pattern(/\A(\d+)\z/) { |digits| digits.size < 4 }
			prop :slug, String, &(RactorPipelines::Strip >> RactorPipelines::Downcase >> RactorPipelines::Immutable)
			prop :numbers, Literal::Array(Integer), &Literal::Array(Integer)
			prop :codes, RactorPipelines::Codes, &RactorPipelines::Codes
		end

		class RactorCoercedChild < RactorCoerced
			prop :extra, Integer
		end

		class RactorParent < Literal::Struct
			prop :id, Integer
			check(:id, "must be positive", &:positive?)
		end

		class RactorBare < RactorParent
		end

		class RactorParentData < Literal::Data
			prop :id, Integer
		end

		class RactorBareData < RactorParentData
		end

		class RactorLoaded < Literal::Data
			prop :id, Integer
		end

		LOADED = Ractor.make_shareable(RactorLoaded.from_props(id: 1))

		[RactorStruct, RactorData, RactorObject, RactorRange, RactorChild, RactorCoercedChild, RactorCoerced, RactorBare, RactorBareData].each do |shape|
			Literal.make_shareable(shape)
		end

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

			assert_equal error.message, "Cannot define :extra on #{RactorObject}, because it is frozen."
		end

		test "a shape that was never made shareable says so inside a Ractor" do
			message = in_ractor do
				RactorUnshared.new(name: "x")
			rescue Ractor::IsolationError => error
				error.message
			end

			assert_equal message, "#{RactorUnshared} can't be built outside the main Ractor until it is passed to Literal.make_shareable."
		end

		test "patterns, composed coercions and collection coercions run inside a Ractor" do
			coerced = in_ractor do
				value = RactorCoerced.new(code: "12", slug: "  Hello ", numbers: [1, 2], codes: ["7"])
				[value.code, value.slug, value.slug.frozen?, value.numbers.class, value.numbers.to_a, value.codes.to_a, RactorCoerced.literal_properties[:code].type === "12345"]
			end

			assert_equal coerced, ["12", "hello", true, Literal::Array, [1, 2], ["7"], false]
		end

		test "methods a shape inherits work inside a Ractor" do
			outcome = in_ractor do
				bare = RactorBare.new(id: 1)
				bare.id = 2

				begin
					bare.id = -1
				rescue Literal::CheckError
					nil
				end

				[bare.id, RactorBareData.new(id: 1).with(id: 3).id]
			end

			assert_equal outcome, [2, 3]
		end

		test "a shape whose superclass was never built can be built inside a Ractor" do
			child = in_ractor { RactorChild.new(id: 1, name: "child") }

			assert_equal child.to_h, { id: 1, name: "child" }
		end

		test "a shareable value loaded from props is read inside a Ractor" do
			outcome = in_ractor { [LOADED.to_h, LOADED.hash == LOADED.hash] }

			assert_equal outcome, [{ id: 1 }, true]
		end

		test "making a shape shareable materializes the deferred types it reaches" do
			deferred = RactorStruct.literal_properties[:next].type.literal_child_types.first

			assert deferred.materialized?
			assert Ractor.shareable?(deferred)
		end
	end
end
