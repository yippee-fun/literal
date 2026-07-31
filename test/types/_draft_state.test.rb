# frozen_string_literal: true

include Literal::Types

class DraftStateAddress < Literal::Data
	prop :street, String
end

test "matches the type itself" do
	assert _DraftState(String) === "a"
	refute _DraftState(String) === 1
	assert _DraftState(DraftStateAddress) === DraftStateAddress.new(street: "1 Main St")
end

test "relaxes frozen constraints" do
	type = _DraftState(_Frozen(_Array(String)))

	assert type === ["a"]
	assert type === ["a"].freeze
	refute type === [1]
end

test "admits drafts of Literal::Properties classes, including subtypes" do
	type = _DraftState(DraftStateAddress)

	assert type === Literal::Draft(DraftStateAddress).new
	assert type === Literal::Draft(Class.new(DraftStateAddress)).new
	refute type === Literal::Draft(Class.new(Literal::Data)).new
end

test "relaxes through nilable and union types" do
	assert _DraftState(_Nilable(DraftStateAddress)) === Literal::Draft(DraftStateAddress).new
	assert _DraftState(_Nilable(DraftStateAddress)) === nil
	assert _DraftState(_Union(Integer, _Frozen(DraftStateAddress))) === Literal::Draft(DraftStateAddress).new
	assert _DraftState(_Union(Integer, _Frozen(DraftStateAddress))) === 1
end

test "defers deferred types instead of materializing them" do
	type = _DraftState(_Deferred { DraftStateNotYetDefined })

	Object.const_set(:DraftStateNotYetDefined, Class.new(Literal::Data) { prop :x, Integer })

	assert type === DraftStateNotYetDefined.new(x: 1)
	assert type === Literal::Draft(DraftStateNotYetDefined).new
end

test "does not widen slots typed as draft classes" do
	type = _DraftState(Literal::Draft(DraftStateAddress))

	assert type === Literal::Draft(DraftStateAddress).new
	refute type === DraftStateAddress.new(street: "1 Main St")
end

test "does not include the unset sentinel" do
	refute _DraftState(DraftStateAddress) === Literal::Undefined
end

test "subtyping delegates to the relaxed type" do
	assert_subtype _DraftState(String), _DraftState(String)
	assert_subtype String, _DraftState(_Frozen(String))
	assert_subtype Literal::Draft(DraftStateAddress), _DraftState(DraftStateAddress)
	refute_subtype Integer, _DraftState(String)
end

test "inspects as _DraftState" do
	assert_equal _DraftState(String).inspect, "_DraftState(String)"
end
