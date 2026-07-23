# frozen_string_literal: true

class DraftExample < Literal::Data
	prop :name, String
	prop :id, Integer
	prop :age, Integer, default: 18
	prop :nickname, _Nilable(String)
end

test "drafts have optional, writable versions of the properties" do
	draft = Literal::Draft(DraftExample).new

	assert_equal draft.name, Literal::Undefined

	draft.name = "John"

	assert_equal draft.name, "John"
	assert_raises(Literal::TypeError) { draft.id = "1" }
end

test "drafts reject nil for properties that aren't nilable" do
	draft = Literal::Draft(DraftExample).new

	assert_raises(Literal::TypeError) { draft.name = nil }
end

test "drafts are subclasses of Literal::Draft" do
	draft_class = Literal::Draft(DraftExample)

	assert draft_class < Literal::Draft
	assert Literal::Draft === draft_class.new
	assert_equal draft_class.__type__, DraftExample
end

test "draft classes match drafts of the same type from separate calls" do
	a = Literal::Draft(DraftExample)
	b = Literal::Draft(DraftExample)

	assert a === b.new
	assert_equal Literal.subtype?(a, b), true
	assert_equal Literal.subtype?(b, a), true
end

test "draft subtyping is covariant in the drafted type" do
	child = Class.new(DraftExample)

	parent_draft = Literal::Draft(DraftExample)
	child_draft = Literal::Draft(child)

	assert parent_draft === child_draft.new
	refute child_draft === parent_draft.new
	assert_equal Literal.subtype?(child_draft, parent_draft), true
	assert_equal Literal.subtype?(parent_draft, child_draft), false
end

test "draft classes can be used as property types" do
	holder = Class.new(Literal::Data) do
		prop :draft, Literal::Draft(DraftExample)
	end

	draft = Literal::Draft(DraftExample).new

	assert_equal holder.new(draft:).draft, draft
	assert_raises(Literal::TypeError) { holder.new(draft: "nope") }
end

test "drafts are named after the class they draft" do
	assert_equal Literal::Draft(DraftExample).name, "Literal::Draft(#{DraftExample.name})"
end

test "Draft requires a Literal::Properties class" do
	error = assert_raises(Literal::ArgumentError) { Literal::Draft(String) }

	assert error.message.include?("Literal::Properties")
end

test "finalize builds the drafted type, applying its defaults" do
	draft = Literal::Draft(DraftExample).new
	draft.name = "John"
	draft.id = 1

	finalized = draft.finalize

	assert_equal finalized, DraftExample.new(name: "John", id: 1)
	assert_equal finalized.age, 18
	assert_equal finalized.frozen?, true
end

test "finalize takes properties to assign as part of finalization" do
	draft = Literal::Draft(DraftExample).new
	draft.name = "John"

	finalized = draft.finalize(id: 1, nickname: "Johnny")

	assert_equal finalized, DraftExample.new(name: "John", id: 1, nickname: "Johnny")
	assert_equal draft.id, 1
end

test "properties passed to finalize are coerced and type checked" do
	klass = Class.new(Literal::Struct) do
		prop :name, String, reader: :public do |value|
			value.to_s.strip
		end
	end

	draft = Literal::Draft(klass).new

	assert_equal draft.finalize(name: " John ").name, "John"

	unfinalizable = Literal::Draft(DraftExample).new(name: "John", id: 1)

	assert_raises(Literal::TypeError) { unfinalizable.finalize(id: "2") }
end

test "finalize raises for properties the draft doesn't have" do
	draft = Literal::Draft(DraftExample).new(name: "John", id: 1)

	assert_raises(NameError) { draft.finalize(shoe_size: 9) }
end

test "finalize raises for unset required properties" do
	draft = Literal::Draft(DraftExample).new(name: "John")

	error = assert_raises(Literal::ArgumentError) { draft.finalize }

	assert error.message.include?("Missing property :id")
end

test "finalize distinguishes unset from explicitly nil" do
	klass = Class.new(Literal::Data) do
		prop :note, _Nilable(String), default: "a note"
	end

	unset = Literal::Draft(klass).new

	assert_equal unset.finalize.note, "a note"

	set_nil = Literal::Draft(klass).new
	set_nil.note = nil

	assert_equal set_nil.finalize.note, nil
end

test "draft coercions apply to everything except unset values" do
	klass = Class.new(Literal::Struct) do
		prop :name, String, reader: :public do |value|
			value.to_s.strip
		end
	end

	draft = Literal::Draft(klass).new

	assert_equal draft.name, Literal::Undefined

	draft.name = " John "

	assert_equal draft.name, "John"
	assert_equal draft.finalize.name, "John"
end

test "drafts keep positional properties positional" do
	klass = Class.new(Literal::Data) do
		prop :x, Integer, :positional
		prop :y, Integer, :positional
	end

	draft = Literal::Draft(klass).new(1, 2)

	assert_equal draft.finalize, klass.new(1, 2)
end
