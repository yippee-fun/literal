# frozen_string_literal: true

include Literal::Types

test ">= and <= agree with subtype? on every pair" do
	json = _Deferred { _Union(String, Integer, nil, _Array(json), _Hash(String, json)) }
	list = _Deferred { _Nilable(_Tuple(Integer, list)) }

	types = [
		String,
		Integer,
		Numeric,
		Object,
		NilClass,
		TrueClass,
		Enumerable,
		Array,
		"a",
		1,
		1.0,
		:a,
		nil,
		true,
		false,
		1..5,
		_Any,
		_Void,
		_Never,
		_Boolean,
		_Truthy,
		_Falsy,
		_Union(true, false),
		_Union(String, Integer),
		_Union("a", :a),
		_Union(1, 2),
		_Nilable(String),
		_Nilable(_Union(true, false)),
		_TaggedUnion(string: String, integer: Integer),
		Literal::Result(String, Integer),
		Literal::Success(String),
		Literal::Failure(Integer),
		_Integer(1..5),
		_Integer(0..),
		_String(size: 1),
		_Constraint(Integer, positive?: true),
		_Array(String),
		_Array(_Union(String, Symbol)),
		_Array(_Boolean),
		_Array(_Union(true, false)),
		_Hash(String, Integer),
		_Set(String),
		_Tuple(String, Integer),
		_Map(name: String),
		_Frozen(String),
		_Not(Integer),
		_Instance(String),
		_Class(Numeric),
		_Descendant(Numeric),
		_Kind(Numeric),
		_Interface(:to_s),
		_SameObject(:a),
		_SameObject("abc"),
		_Symbol(size: 1),
		_String(size: 3),
		_Constraint(_Tuple(String), size: 1),
		_Tuple(String),
		_Constraint(_Boolean, frozen?: true),
		_Range(Integer),
		_Enumerable(String),
		_JSONData,
		Literal::Array(String),
		Literal::Hash(String, Integer),
		Literal::Set(String),
		Literal::Tuple(String, Integer),
		_Deferred { String },
		_Deferred { _Union(true, false) },
		_Deferred { _Deferred { _Union(true, false) } },
		json,
		list,
		_Array(json),
		_Array(list),
	]

	types.each do |supertype|
		types.each do |subtype|
			expected = Literal.subtype?(subtype, supertype)

			if Literal::Type === supertype
				assert (supertype >= subtype) == expected do
					"Expected #{supertype.inspect} >= #{subtype.inspect} to be #{expected}."
				end
			end

			if Literal::Type === subtype
				assert (subtype <= supertype) == expected do
					"Expected #{subtype.inspect} <= #{supertype.inspect} to be #{expected}."
				end
			end
		end
	end
end

test "comparisons take apart what's on the left" do
	assert _Boolean >= _Union(true, false)
	assert _Nilable(_Boolean) >= _Union(true, nil, false)
	assert _Union(String, Integer) >= _TaggedUnion(string: String, integer: Integer)
	assert _Union(Literal::Success(String), Literal::Failure(Integer)) >= Literal::Result(String, Integer)
	assert _Boolean >= _Deferred { _Union(true, false) }
	assert _Union(true, false) <= _Boolean
	refute _Boolean >= _Union(true, nil)
end
