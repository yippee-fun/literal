# frozen_string_literal: true

class ::SerializedColor < Literal::Enum(Integer)
	Red = new(1)
	Green = new(2)
end

class ::SerializedSize < Literal::Enum(Symbol)
	Small = new(:small)
	Large = new(:large)
end

class ::SerializedRelease < Literal::Enum(Date)
	First = new(Date.new(2024, 1, 1))
	Second = new(Date.new(2025, 1, 1))
end

ActiveJob.deprecator.silence do
	ActiveJob::Serializers.add_serializers(Literal::Rails::EnumSerializer)
end

def round_trip(*arguments)
	serialized = ActiveJob::Arguments.serialize(arguments)
	ActiveJob::Arguments.deserialize(JSON.parse(JSON.generate(serialized)))
end

test "the serializer declares Literal::Enum as its class" do
	assert_equal Literal::Rails::EnumSerializer.instance.klass, Literal::Enum
end

test "the serializer is registered without a deprecation warning" do
	original_behavior = ActiveJob.deprecator.behavior
	ActiveJob.deprecator.behavior = :raise

	begin
		ActiveJob::Serializers.add_serializers(Literal::Rails::EnumSerializer)
	ensure
		ActiveJob.deprecator.behavior = original_behavior
	end
end

test "an enum serializes to a hash" do
	assert_equal ActiveJob::Arguments.serialize([SerializedColor::Red]), [
{
		"_aj_serialized" => "Literal::Rails::EnumSerializer",
		"class" => "SerializedColor",
		"value" => 1,
	},
]
end

test "an enum with integer values round-trips" do
	assert_equal round_trip(SerializedColor::Red, SerializedColor::Green), [SerializedColor::Red, SerializedColor::Green]
end

test "an enum with symbol values round-trips" do
	assert_equal round_trip(SerializedSize::Large), [SerializedSize::Large]
end

test "an enum with date values round-trips" do
	assert_equal round_trip(SerializedRelease::Second), [SerializedRelease::Second]
end

test "enums nested in other arguments round-trip" do
	assert_equal round_trip({ size: SerializedSize::Small, colors: [SerializedColor::Green] }), [{ size: SerializedSize::Small, colors: [SerializedColor::Green] }]
end

test "deserializing an unknown value raises" do
	error = assert_raises(ActiveJob::DeserializationError) do
		ActiveJob::Arguments.deserialize([
{
			"_aj_serialized" => "Literal::Rails::EnumSerializer",
			"class" => "SerializedColor",
			"value" => 99,
		},
])
	end

	assert KeyError === error.cause
end

test "deserializing a class that isn't an enum raises" do
	error = assert_raises(ActiveJob::DeserializationError) do
		ActiveJob::Arguments.deserialize([
{
			"_aj_serialized" => "Literal::Rails::EnumSerializer",
			"class" => "String",
			"value" => "foo",
		},
])
	end

	assert ArgumentError === error.cause
end
