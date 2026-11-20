# frozen_string_literal: true

class RailsActiveRecordEnumTest < Quickdraw::Test
	class ::RecordColor < Literal::Enum(Integer)
		Red = new(1)
		Green = new(2)
	end

	class ::EnumRecord < ActiveRecord::Base
		literal_enum :color, RecordColor
	end

	test "declaring a literal_enum doesn't touch the database" do
		refute ActiveRecord::Base.connected?
		assert EnumRecord.respond_to?(:literal_enum)
	end

	if defined?(SQLite3)
		class ::EnumRecordBase < ActiveRecord::Base
			self.abstract_class = true
			establish_connection(adapter: "sqlite3", database: ":memory:", pool: 1)
		end

		class ::SQLiteEnumRecord < EnumRecordBase
			self.table_name = "enum_records"
			literal_enum :color, RecordColor
		end

		def with_enum_records_table
			EnumRecordBase.connection_pool.with_connection do |connection|
				connection.create_table(:enum_records, force: true) do |t|
					t.integer :color
				end

				yield connection
			end
		end

		test "wraps the column type" do
			with_enum_records_table do
				type = SQLiteEnumRecord.type_for_attribute(:color)

				assert Literal::Rails::EnumType === type
				assert ActiveModel::Type::Integer === type.subtype
			end
		end

		test "serializes query placeholders through the column type" do
			with_enum_records_table do
				substitute = ActiveRecord::StatementCache::Substitute.new
				type = SQLiteEnumRecord.type_for_attribute(:color)

				assert_equal type.subtype.serialize(substitute), type.serialize(substitute)
			end
		end

		test "round-trips through an integer column" do
			with_enum_records_table do |connection|
				record = SQLiteEnumRecord.create!(color: "2")

				assert_equal RecordColor::Green, record.color
				assert_equal 2, connection.select_value("SELECT color FROM enum_records")
				assert_equal RecordColor::Green, SQLiteEnumRecord.find(record.id).color
				assert_equal record, SQLiteEnumRecord.find_by(color: RecordColor::Green)
			end
		end
	end
end
