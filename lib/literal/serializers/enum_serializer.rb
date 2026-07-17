# frozen_string_literal: true

class Literal::EnumSerializer < Literal::Serializer
  def type = Literal::Enum

  def child_types(type)
    [backing_type(type)]
  end

  def json_schema(type, generator: nil)
    { **json_schema_for(backing_type(type), generator:), "enum" => type.values }
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
