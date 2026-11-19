# frozen_string_literal: true

class ::TypedPermissions < Literal::Flags8
	define(read: 0, write: 1)
end

class ::FlagsTypeRecord
	include ActiveModel::Model
	include ActiveModel::Attributes
	include ActiveModel::Dirty

	attribute :permissions, Literal::Rails::FlagsType.new(TypedPermissions)
end

type = Literal::Rails::FlagsType.new(TypedPermissions)

test "casts and deserializes bit strings" do
	assert_equal type.cast("00000011"), TypedPermissions.new(read: true, write: true)
	assert_equal type.deserialize("00000010"), TypedPermissions.new(write: true)
end

test "casts integers" do
	assert_equal type.cast(3), TypedPermissions.new(read: true, write: true)
end

# It writes bit strings, so an integer from the database is a bit string an
# integer column has read as decimal.
test "refuses to deserialize integers" do
	assert_raises(Literal::ArgumentError) { type.deserialize(10) }
end

test "passes flags and nil through" do
	flags = TypedPermissions.new(read: true)

	assert type.cast(flags).equal?(flags)
	assert_equal type.cast(nil), nil
	assert_equal type.deserialize(nil), nil
end

test "serializes to a bit string" do
	assert_equal type.serialize(TypedPermissions.new(read: true)), "00000001"
	assert_equal type.serialize(nil), nil
end

test "refuses input that isn't a bit string or an integer the flags can hold" do
	assert_raises(Literal::ArgumentError) { type.cast("junk") }
	assert_raises(Literal::ArgumentError) { type.deserialize("0000002") }
	assert_raises(Literal::TypeError) { type.cast(256) }
end

test "assigning equal flags leaves a record unchanged" do
	record = FlagsTypeRecord.new(permissions: TypedPermissions.new(read: true))
	record.changes_applied

	record.permissions = TypedPermissions.new(read: true)
	refute record.changed?

	record.permissions = "00000001"
	refute record.changed?

	record.permissions = 3
	assert record.permissions_changed?
end
