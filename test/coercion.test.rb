# frozen_string_literal: true

test "coercions compose in both directions" do
	a = Literal::Coercion { |it| it + [:a] }
	b = Literal::Coercion { |it| it + [:b] }

	assert Literal::Coercion === (a >> b)
	assert_equal (a >> b).call([]), [:a, :b]
	assert_equal (a << b).call([]), [:b, :a]
	assert_equal (a >> proc { |it| it + [:p] }).call([]), [:a, :p]
end

test "composing a coercion into a seal returns a seal whose coercion runs first" do
	strip = Literal::Coercion { |it| it.strip }

	assert Literal::Seal === (strip >> Literal::Coercions::Immutable)
	assert Literal::Seal === (Literal::Coercions::Immutable << strip)
end

test "a coercion can never come after a seal" do
	seal = Literal::Seal { |it| it.frozen? ? it : it.dup.freeze }
	coercion = Literal::Coercion { |it| it }

	assert_raises(Literal::ArgumentError) { seal >> coercion }
	assert_raises(Literal::ArgumentError) { seal >> proc { |it| it } }
	assert_raises(Literal::ArgumentError) { coercion << seal }
	assert_raises(Literal::ArgumentError) { seal >> (coercion >> Literal::Coercions::Immutable) }
	assert_raises(Literal::ArgumentError) { (coercion >> Literal::Coercions::Immutable) << seal }
end

test "seals are not callable, so Proc#>> rejects them at composition time" do
	assert_raises(TypeError) { proc { |it| it } >> Literal::Coercions::Immutable }
end

class CoercionSealSplit < Literal::Struct
	prop :name, String, reader: :public, &(
		Literal::Coercion { |it| it.strip } >> Literal::Coercions::Immutable
	)
end

test "a composed pipeline splits into the property's coercion and seal slots" do
	property = CoercionSealSplit.literal_properties[:name]

	assert property.coercion
	assert property.seal

	constructed = CoercionSealSplit.new(name: " Joel ")

	assert_equal constructed.name, "Joel"
	assert constructed.name.frozen?

	# from_props is a final-value path: the seal applies, the coercion doesn't.
	restored = CoercionSealSplit.from_props(name: " Joel ")

	assert_equal restored.name, " Joel "
	assert restored.name.frozen?
end

class CoercionContext < Literal::Struct
	prop :plain, String, reader: :public do |value|
		tag(value)
	end

	prop :composed, String, reader: :public, &(
		Literal::Coercion { |it| tag(it) } >> proc { |it| tag(it) }
	)

	prop :sealed, String, reader: :public, &(
		(Literal::Coercions::Immutable << proc { |it| tag(it) }) << proc { |it| tag(it) }
	)

	private def tag(value)
		"#{value}!"
	end
end

test "composed coercion stages see the instance context like an uncomposed block" do
	object = CoercionContext.new(plain: "a", composed: "b", sealed: "c")

	assert_equal object.plain, "a!"
	assert_equal object.composed, "b!!"
	assert_equal object.sealed, "c!!"
	assert object.sealed.frozen?
end
