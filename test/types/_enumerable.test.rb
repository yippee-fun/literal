# frozen_string_literal: true

class EnumerableTypeTest < Quickdraw::Test
	include Literal::Types

	test "===" do
		assert _Enumerable(String) === ["a", "b", "c"]
		assert _Enumerable(Integer) === Set[1, 2, 3]

		refute _Enumerable(String) === [1, "a", :symbol]
	end

	test "=== iterates finite enumerables and those that don't report a size" do
		assert _Enumerable(Integer) === (1..3)
		assert _Enumerable(Integer) === [1, 2, 3].each

		unsized = Class.new do
			include Enumerable

			def each
				yield 1
				yield 2
			end
		end

		assert _Enumerable(Integer) === unsized.new
		refute _Enumerable(String) === unsized.new

		measured = Class.new(unsized) do
			def size(unit) = 2
		end

		assert _Enumerable(Integer) === measured.new
	end

	test "=== raises for enumerables of unknown or infinite size" do
		assert_raises(Literal::ArgumentError) { _Enumerable(Integer) === (1..) }
		assert_raises(Literal::ArgumentError) { _Enumerable(Integer) === Enumerator.new { |y| loop { y << 1 } } }
		assert_raises(Literal::ArgumentError) { _Enumerable(Integer) === (1..).lazy.map { |n| n } }
	end

	test "hierarchy" do
		assert_subtype _Enumerable(Array), _Enumerable(Enumerable)
		assert_subtype _Enumerable(Set), _Enumerable(Enumerable)

		refute_subtype _Enumerable(String), _Enumerable(Enumerable)
	end
end
