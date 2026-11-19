# frozen_string_literal: true

module Literal::Rails
	if defined?(::ActiveJob)
		require_relative "rails/enum_serializer"
	end

	if defined?(::ActiveRecord::Relation)
		require_relative "rails/relation_type"
		require_relative "rails/active_record_relation_patch"
		::ActiveRecord.extend(ActiveRecordRelationPatch)
	end
end

class Literal::Railtie < Rails::Railtie
	# Active Job reads its custom serializers as soon as ActiveJob::Arguments
	# loads, which may already have happened.
	initializer "literal.active_job_serializers", before: "active_job.custom_serializers" do |app|
		if defined?(::ActiveJob::Railtie)
			require_relative "rails/enum_serializer"
			app.config.active_job.custom_serializers << Literal::Rails::EnumSerializer
		end
	end

	if defined?(::ActiveModel::Type)
		require_relative "rails/enum_type"
		require_relative "rails/flags_type"
		require_relative "rails/enum_macro"

		ActiveSupport.on_load(:active_record) do
			extend Literal::Rails::EnumMacro
		end

		initializer "literal.register_active_model_types" do
			ActiveModel::Type.register(:literal_enum) do |name, type:|
				Literal::Rails::EnumType.new(type)
			end

			ActiveModel::Type.register(:literal_flags) do |name, type:|
				Literal::Rails::FlagsType.new(type)
			end
		end

		if defined?(::ActiveRecord::Type)
			initializer "literal.register_active_record_types" do
				ActiveRecord::Type.register(:literal_enum) do |name, type:|
					Literal::Rails::EnumType.new(type)
				end

				ActiveRecord::Type.register(:literal_flags) do |name, type:|
					Literal::Rails::FlagsType.new(type)
				end
			end
		end
	end
end
