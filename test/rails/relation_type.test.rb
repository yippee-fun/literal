# frozen_string_literal: true

class RelationModel < ActiveRecord::Base
end

class SpecialRelationModel < RelationModel
end

test "relation types are subtypes of Enumerable" do
	assert_subtype ActiveRecord.Relation(RelationModel), Enumerable
end

test "relation types are subtypes of ActiveRecord::Relation and its ancestors" do
	assert_subtype ActiveRecord.Relation(RelationModel), ActiveRecord::Relation
	assert_subtype ActiveRecord.Relation(RelationModel), Object

	refute_subtype ActiveRecord::Relation, ActiveRecord.Relation(RelationModel)
	refute_subtype Enumerable, ActiveRecord.Relation(RelationModel)
end

test "relation types are covariant in the model class" do
	assert_subtype ActiveRecord.Relation(SpecialRelationModel), ActiveRecord.Relation(RelationModel)
	refute_subtype ActiveRecord.Relation(RelationModel), ActiveRecord.Relation(SpecialRelationModel)
end

test "relation types compose with other types" do
	assert_subtype ActiveRecord.Relation(RelationModel), Literal::Types._Union(Enumerable, nil)
end

test "relation types are equal for the same model" do
	assert_equal ActiveRecord.Relation(RelationModel), ActiveRecord.Relation(RelationModel)
	refute_equal ActiveRecord.Relation(RelationModel), ActiveRecord.Relation(SpecialRelationModel)
end
