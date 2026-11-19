# frozen_string_literal: true

class Example < Literal::Flags8
	define(
		bold: 0,
		italic: 1,
		underlined: 2,
	)
end

test "with" do
	a = Example.new(italic: true, underlined: true)
	b = a.with(bold: true, underlined: false)

	refute a.bold?
	assert a.italic?
	assert a.underlined?

	assert b.bold?
	assert b.italic?
	refute b.underlined?
end

test "from_array" do
	flags = Example.from_array([false, false, false, false, false, false, false, true])

	assert flags.bold?
end

test "to bit string" do
	flags = Example.new(italic: true)
	assert_equal("00000010", flags.to_bit_string)
end

test "from bit string" do
	flags = Example.from_bit_string("00000010")

	refute flags.bold?
	assert flags.italic?
	refute flags.underlined?
end

test "hash-like" do
	flags = Example.new(
		bold: true,
	)

	assert flags[:bold]
	refute flags[:italic]
	refute flags[:underlined]
end

test "#to_h" do
	flags = Example.new(
		bold: true,
		italic: true,
	)

	assert_equal(flags.to_h, {
		bold: true,
		italic: true,
		underlined: false,
	})
end

test "#map (via Enumerable)" do
	flags = Example.new(bold: true)

	assert_equal(flags.map.to_a, [
		[:bold, true],
		[:italic, false],
		[:underlined, false],
	])
end

test ".from_tokens" do
	flags = Example.from_tokens([:bold, :italic])

	assert flags.bold?
	assert flags.italic?
	refute flags.underlined?
end

test "#to_tokens" do
	flags = Example.new(bold: true, italic: true)
	assert_equal([:bold, :italic], flags.to_tokens)
end

test "#to_a" do
	flags = Example.new(bold: true)
	assert_equal([false, false, false, false, false, false, false, true], flags.to_a)
end

test "#deconstruct_keys with no filter" do
	flags = Example.new(bold: true)

	assert_equal({
		bold: true,
		italic: false,
		underlined: false,
	}, flags.deconstruct_keys)
end

test "#deconstruct_keys with filter" do
	flags = Example.new(bold: true)

	assert_equal({
		bold: true,
		underlined: false,
	}, flags.deconstruct_keys([:bold, :underlined]))
end

test "#each without a block returns an enumerator" do
	enumerator = Example.new(bold: true).each

	assert Enumerator === enumerator
	assert_equal enumerator.size, 3
	assert_equal enumerator.to_a, [[:bold, true], [:italic, false], [:underlined, false]]
end

test ".keys" do
	assert_equal Example.keys, [:bold, :italic, :underlined]
end

class OtherExample < Literal::Flags8
	define(bold: 0)
end

test "flags with the same value are equal" do
	assert_equal Example.new(bold: true), Example.new(bold: true)
	assert Example.new(bold: true).eql?(Example.from_int(1))
	assert_equal Example.new(bold: true).hash, Example.from_int(1).hash
	assert_equal({ Example.new(bold: true) => 1 }[Example.from_tokens([:bold])], 1)

	refute_equal Example.new(bold: true), Example.new(italic: true)
	refute_equal Example.new(bold: true), OtherExample.new(bold: true)
	refute_equal Example.new(bold: true), 1
	refute Example.new(bold: true) == BasicObject.new
end
