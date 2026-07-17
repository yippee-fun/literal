# frozen_string_literal: true

class Literal::EnumSerializer < Literal::Serializer
  def type = Literal::Enum

  def child_types(type)
    [backing_type(type)]
  end

  def json_schema(type, generator: nil)
    backing = backing_type(type)
    values = type.values.map { |value| serialize_contents(value, type: backing) }

    { **json_schema_for(backing, generator:), "enum" => values }
  end

  def serialize(value, type:)
    serialize_contents(value.value, type: backing_type(type))
  end

  def deserialize(data, type:)
    type.coerce(deserialize_contents(data, type: backing_type(type)))
  end

  private def backing_type(type)
    type.literal_properties[:value].type
  end
end
