# frozen_string_literal: true

test "props support predicates" do
	example = Class.new(Literal::Struct) do
		prop :enabled, _Boolean, predicate: :public
	end

	assert_equal example.new(enabled: true).enabled?, true
	assert_equal example.new(enabled: false).enabled?, false
end

class StructOptional < Literal::Struct
	prop? :name, String
end

test "prop? defines a public reader and writer by default" do
	example = StructOptional.new

	assert_equal example.name, Literal::Undefined

	example.name = "Joel"
	assert_equal example.name, "Joel"

	assert_raises(Literal::TypeError) { example.name = 1 }
end

test "prop? honours explicitly supplied visibility options" do
	example = Class.new(Literal::Struct) do
		prop? :name, String, reader: :private, writer: :private
	end.new

	refute example.respond_to?(:name)
	refute example.respond_to?(:name=)
	assert_equal example.__send__(:name), Literal::Undefined
end

test "prop? serializes undefined by omission and restores it from a missing key" do
	context = Literal::SerializationContext.new
	example = StructOptional.new

	assert_equal context.serialize(example, type: StructOptional), {}

	deserialized = context.deserialize({}, type: StructOptional)
	assert_equal deserialized.name, Literal::Undefined

	example.name = "Joel"
	assert_equal context.serialize(example, type: StructOptional), { "name" => "Joel" }
end

test "Literal::Data prop? keeps a public reader and no writer" do
	example = Class.new(Literal::Data) do
		prop? :name, String
	end.new

	assert_equal example.name, Literal::Undefined
	refute example.respond_to?(:name=)
end

class Person < Literal::Struct
	prop :name, String
end

class Student < Person
	prop :final_grade, Integer
end

test do
	person = Person.new(name: "Joel")
	assert_equal person.name, "Joel"
end

test do
	person = Person.new(name: "Joel")
	person.name = "Jill"

	assert_equal person.name, "Jill"
end

test do
	person = Person.new(name: "Joel")
	assert_equal person.to_h, { name: "Joel" }
end

test do
	a = Person.new(name: "Joel")
	b = Person.new(name: "Joel")

	assert_equal a, b
end

test do
	a = Person.new(name: "Joel")
	b = Person.new(name: "Jill")

	refute_equal a, b
end

test do
	a = Person.new(name: "Joel")
	b = Student.new(name: "Joel", final_grade: 90)

	refute_equal a, b
end

# Marshal doesn't work with anonymous classes
class ::RootStruct < Literal::Struct
	prop :name, String
end

test "marshalling" do
	a = RootStruct.new(name: "Joel")
	b = Marshal.load(Marshal.dump(a))

	assert_equal b, a
end

test "marshalling a frozen struct" do
	a = RootStruct.new(name: "Joel")
	a.freeze

	b = Marshal.load(Marshal.dump(a))

	assert_equal b, a
	assert b.frozen?
end

test "as_pack/from_pack" do
	a = RootStruct.new(name: "Joel")
	a.freeze

	b = RootStruct.from_pack(a.as_pack)

	assert_equal b, a
	assert b.frozen?
end

test "can be deconstructed" do
	person = Person.new(name: "Joel")
	assert_equal person.deconstruct, ["Joel"]
end

test "can be deconstructed with keys" do
	person = Person.new(name: "Joel")

	assert_equal person.deconstruct_keys([:name]), { name: "Joel" }
	assert_equal person.deconstruct_keys(nil), { name: "Joel" }
end

test "can be indexed" do
	person = Person.new(name: "Joel")
	assert_equal person[:name], "Joel"
end

test "returns nil for unknown keys" do
	person = Person.new(name: "Joel")

	assert_raises(NameError) { person[:age] }
	assert_equal "Joel", person["name"]
	assert_raises(TypeError) { person[0] }
end

class WithKeywordPropertyNames < Literal::Struct
	prop :begin, String
	prop :end, String
	prop :module, _Nilable(Module)
end

test do
	with_keyword_property_names = WithKeywordPropertyNames.new(begin: "start", end: "finish")
	assert_equal(with_keyword_property_names.to_h, { :begin => "start", :end => "finish", :module => nil })
	assert_equal(with_keyword_property_names, with_keyword_property_names)
	assert_equal(with_keyword_property_names, with_keyword_property_names.dup)
	assert_equal(with_keyword_property_names.hash, with_keyword_property_names.dup.hash)
	assert_equal(with_keyword_property_names[:begin], "start")
	assert_equal(with_keyword_property_names[:end], "finish")
	assert_equal(with_keyword_property_names[:module], nil)
	assert_equal(with_keyword_property_names["begin"], "start")
	assert_equal(with_keyword_property_names["end"], "finish")
	assert_equal(with_keyword_property_names["module"], nil)
	assert_equal(with_keyword_property_names.begin, "start")
	assert_equal(with_keyword_property_names.end, "finish")
	assert_equal(with_keyword_property_names.module, nil)
	with_keyword_property_names[:begin] = "start2"
	with_keyword_property_names.end = "finish2"
	assert_equal(with_keyword_property_names.to_h, { :begin => "start2", :end => "finish2", :module => nil })
end
