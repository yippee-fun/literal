# frozen_string_literal: true

class Person < Literal::Struct
	prop :name, String, description: "The person's name"
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

test "struct accepts and stores description" do
	prop = Person.literal_properties[:name]
	assert_equal prop.description, "The person's name"
	assert prop.description?

	prop = Student.literal_properties[:final_grade]
	assert_equal prop.description, nil
	refute prop.description?
end
