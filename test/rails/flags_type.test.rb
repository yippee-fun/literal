# frozen_string_literal: true

class RailsFlagsTypeTest < Quickdraw::Test
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
	integer_type = Literal::Rails::FlagsType.new(TypedPermissions, format: :integer)

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

	test "casts blank input to nil" do
		assert_equal type.cast(""), nil
		assert_equal type.cast("  "), nil
		assert_equal integer_type.cast(""), nil
	end

	test "serializes to a bit string" do
		assert_equal type.serialize(TypedPermissions.new(read: true)), "00000001"
		assert_equal type.serialize(nil), nil
	end

	test "refuses input that isn't a bit string or an integer the flags can hold" do
		assert_raises(Literal::ArgumentError) { type.cast("junk") }
		assert_raises(Literal::ArgumentError) { type.cast(:junk) }
		assert_raises(Literal::ArgumentError) { type.cast(:" ") }
		assert_raises(Literal::ArgumentError) { type.deserialize("0000002") }
		assert_raises(Literal::ArgumentError) { type.deserialize("") }
		assert_raises(Literal::TypeError) { type.cast(256) }
		assert_raises(Literal::TypeError) { type.cast(-1) }
	end

	test "the integer format reads and writes integers" do
		flags = TypedPermissions.new(read: true, write: true)

		assert_equal integer_type.serialize(flags), 3
		assert_equal integer_type.serialize(nil), nil
		assert_equal integer_type.deserialize(3), flags
		assert_equal integer_type.deserialize("3"), flags
		assert_equal integer_type.deserialize(nil), nil
	end

	test "the integer format casts flags, integers and bit strings" do
		flags = TypedPermissions.new(read: true, write: true)

		assert integer_type.cast(flags).equal?(flags)
		assert_equal integer_type.cast(3), flags
		assert_equal integer_type.cast("00000011"), flags
	end

	test "the integer format refuses anything but an integer the flags can hold" do
		assert_raises(Literal::TypeError) { integer_type.deserialize("256") }
		assert_raises(Literal::TypeError) { integer_type.deserialize("-1") }
		assert_raises(Literal::TypeError) { integer_type.deserialize("3 ") }
		assert_raises(Literal::TypeError) { integer_type.deserialize("junk") }
		assert_raises(Literal::TypeError) { integer_type.deserialize(256) }
		assert_raises(Literal::TypeError) { integer_type.deserialize(-1) }
		assert_raises(Literal::TypeError) { integer_type.deserialize(1.0) }
		assert_raises(Literal::TypeError) { integer_type.cast(256) }
		assert_raises(Literal::ArgumentError) { integer_type.cast("junk") }
	end

	test "types are equal only with the same flags and format" do
		assert_equal type, Literal::Rails::FlagsType.new(TypedPermissions)
		assert type.eql?(Literal::Rails::FlagsType.new(TypedPermissions))
		assert_equal type.hash, Literal::Rails::FlagsType.new(TypedPermissions).hash

		refute_equal type, integer_type
		refute type.eql?(integer_type)
		refute_equal type, Literal::Rails::FlagsType.new(Class.new(Literal::Flags8) { define(read: 0) })
	end

	test "refuses an unknown format" do
		assert_raises(Literal::ArgumentError) do
			Literal::Rails::FlagsType.new(TypedPermissions, format: :hex)
		end
	end

	test "the registered type takes a format" do
		Literal::Railtie.initializers.each do |initializer|
			initializer.run(nil) if initializer.name in "literal.register_active_model_types" | "literal.register_active_record_types"
		end

		flags = TypedPermissions.new(write: true)

		assert_equal ActiveModel::Type.lookup(:literal_flags, type: TypedPermissions).serialize(flags), "00000010"
		assert_equal ActiveModel::Type.lookup(:literal_flags, type: TypedPermissions, format: :integer).serialize(flags), 2
		assert_equal ActiveRecord::Type.lookup(:literal_flags, type: TypedPermissions, adapter: :sqlite3).serialize(flags), "00000010"
		assert_equal ActiveRecord::Type.lookup(:literal_flags, type: TypedPermissions, format: :integer, adapter: :sqlite3).serialize(flags), 2
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
end
