# Literal — LLM context

Runtime type system for Ruby. A type = **any object responding to `===`** (`String`, `5..10`, `/re/`, `nil`, `true`, a class, a proc, a Literal type object) — works in `case/when`, `case/in`, `grep`, etc. Generics are functions returning such objects. Violations raise `Literal::TypeError` fast. (`Literal.check(v, t)` / `Literal.subtype?(t, super)` exist but are internals; app code shouldn't need them.)

## Types — `Literal::Types`

`_PascalCase` factories (include the module; `extend Literal::Properties` includes it). Each `_Foo` has nilable `_Foo?`. Prefer plain constants when unconstrained (`String`, not `_String`).

- `_Union(A, B)`, `_Nilable(T)`, `_Not(T)`, `_Boolean`, `_Truthy`, `_Falsy`
- `_Any` (non-nil), `_Any?` (anything), `_Void` (anything; "don't depend on it"), `_Never`
- `_Constraint(T, size: 1..3)` — intersection + attribute constraints (kwarg: `type === value.attr`). `_Intersection` = same. Wrappers: `_String _Integer _Float _Symbol _Time _Date _BigDecimal`
- Plain-collection types: `_Array(T)`, `_Set(T)`, `_Hash(K, V)`, `_Tuple(A, B)`, `_Enumerable(T)`, `_Range(T)`, `_Map(a: String, b: Integer)` (fixed-shape hash)
- Classes: `_Class(C)` (C/subclass itself), `_Descendant(C)` (strict), `_Instance(C)` (`is_a?`), `_Kind(T)` (subtype of T)
- Duck: `_Interface(:m1, :m2)`, `_Callable`, `_Procable`, `_Lambda`, `_Predicate("desc") { |v| }`, `_Pattern(/(\d+)/) { |cap| }`
- `_Frozen(T)`, `_JSONData` (JSON.parse output), `_Deferred { T }` (lazy const resolution; `.materialize`), `_TaggedUnion(tag: T, …)`, `_SameObject(o)` (identity)
- `_Optional(T)` = `_Union(T, Literal::Undefined)` — omittable, ≠ nilable

Unions simplify at construction (`_Never` dropped, single member unwrapped, nil folded in). `Literal::Undefined`: truthy frozen sentinel = "absent", ≠ `nil`. `require "literal/kernel"` → bare `undefined`/`never`/`void`.

## Properties — `extend Literal::Properties`

```ruby
class P < Literal::Object          # or Struct/Data, or extend yourself
	prop :a, String                  # required keyword
	prop :b, _Integer(0..), reader: :public
	prop :c, Integer, :positional    # kinds: :positional :* :keyword(default) :** :&
	prop :d, Symbol, default: :x     # default: frozen object or Proc (instance_exec'd)
	prop? :e, String                 # optional → _Union(T, Literal::Undefined)
	prop :f, _Array(String), &Literal::Array(String)  # block = coercion, pre-check
end
```

Options `reader:/writer:/predicate:`: `false | :public | :protected | :private`; `predicate` generates `a?` (false for unset/Undefined); `description:` string → JSON Schema. Generates `initialize` (kind-aware signature), `to_h`, per-prop methods; `after_initialize` hook if defined. Store order: **coerce → seal → check → assign**.

Inheritance checked: redefined prop keeps kind, ≥ visibility, narrows type (LSP). No new props after a subclass inherited. `K.literal_properties` → Schema (Enumerable of `Literal::Property`, sorted positional → * → keyword → ** → &).

### Slices

```ruby
PName = P.slice(:a)   # anonymous class "P.slice(:a)"; unknown names → NameError
PName.from(p)         # project instance: copies matching prop values (checked, not coerced)
```

Rooted at the deepest ancestor the selection still satisfies (soundness) — a real superclass-line class, not an attribute bag; pattern-matches and serializes like any structure. `slice` + `from` = pass a narrowed view.

### Coercion / Seal

Composable pipelines for `prop` blocks (`&x` via `to_proc`):

- `Literal::Coercion { |v| }` — normalizes input; runs only at input boundaries (initializer, writers, draft assignment), never on final-value paths (`from_props`, `marshal_load`).
- `Literal::Seal { |v| }` — fixes final representation (e.g. freeze); runs on every real store incl. `from_props`/`marshal_load`; must be idempotent, type-preserving. Drafts drop seals until finalize.
- Compose `>>`/`<<`; coercion-after-seal raises; `coercion >> seal` → Seal carrying the coercion.
- Built-ins (`Literal::Coercions`, included by Properties): `Immutable` (seal, shallow dup+freeze), `DeepImmutable` (seal, `Ractor.make_shareable` copy), `NilIfEmpty` (coercion, `""/[]/{}`→nil). Generics compose: `Literal::Array(String) >> Immutable`.

## Data structures

`DataStructure` → `Struct` (mutable, public readers+writers, `[]=`) → `Draft`; `DataStructure` → `Data` (frozen instances, readers only, `Data.define(a: String)` shorthand); `Object` = bare Properties (no readers by default).

All get structural `==`/`eql?`/`hash`, `to_h`, `[](key)`, `deconstruct`/`deconstruct_keys`, Marshal (`as_pack`/`from_pack`, restores frozen state), and:

```ruby
K.from_props(a: "x")  # inverse of to_h: final values, checked NOT coerced (seals apply),
                      # skips initialize/after_initialize; missing props → defaults
K.from(other)         # from_props(other.to_h.slice(*own props)) — e.g. rehydrate a slice
```

### Draft — `Literal::Draft(P)`

Mutable builder mirroring a Properties class: every prop optional (default Undefined), types relaxed (`_Frozen` unwrapped; a Properties-typed slot also accepts a draft of it via `Draft::Type`). Coercions pass Undefined/nested drafts through. `draft.finalize(**overrides)` → real instance: overrides assigned through writers, Undefined dropped, nested drafts finalized depth-first (unless the slot wants a draft), then `P.from_props`. Pure — draft not consumed. Draft classes are types matching any draft of a subtype.

### Enum

```ruby
class Color < Literal::Enum(Integer)  # backing value type; extra props OK
	prop :hex, String
	index :hex, String                  # unique default; index(:k, T, unique: false) { |m| }
	Red = new(1, hex: "#F00")
	Blue = new(2, hex: "#00F")
end
```

Frozen singleton members; class frozen after definition (TracePoint `:end`). `Color[1]`/`.cast`/`.fetch`, `.coerce(1 | :Red | member)`, `Color::Red.value`, `.red?` predicates (snake_cased const), `to_sym`, `name`, Enumerable, `.values`, `.members`, `.where(hex:)`, `.find_by(hex:)`, ordered (`<=>` `succ` `pred` `position_of`), Marshal by value, `to_proc` → coerce.

### Flags

`class F < Literal::Flags8` (8/16/32/64 = width + `pack` format), `define(read: 0, write: 1)` (unique bit positions). `F.new(read: true)`, generated `read?`, immutable `with(write: true)`, `|`/`&`, `to_i/to_tokens/to_h/to_a/to_bit_string` + `from_*` inverses, `pack`/`unpack`, pattern matching.

## Typed collections

`Literal::Array(T)`, `Literal::Set(T)`, `Literal::Hash(K, V)`, `Literal::Tuple(A, B)` → frozen Generic type objects: `===`, `>=`, `new(*elems)`/`[]`, `coerce(plain)`, `to_proc`, `primitive_type`.

Instances wrap plain collection (`__value__`) + element type(s). Not drop-in:

- Every insert checked. Mutators return `self`; non-mutators return new typed collections.
- Type-changing ops take explicit target type: `arr.map(String, &:to_s)` (`Literal::Transforms` table lets known symbol-procs skip element checks), `filter_map`, `flat_map`, `Hash#transform_keys(T,&)`. `narrow(T)`/`widen(T)` re-type.
- Absence → `Literal::Undefined`, never nil: `arr[i]` `first` `pop` `h[k]` `dig`… (block = fallback; `fetch` raises). No Hash default/default_proc.
- `==`: same wrapper class + value, element type ignored; `eql?` requires same type; never `==` plain Array/Hash.
- Most Enumerable removed; kept: `all? any? each_with_index each_with_object find none? one? reduce` + explicit reimplementations. `to_a`/`to_h`/`to_set` → detached copies.
- `partition`/`minmax` → Tuple; `zip`/`product` → Array of Tuples; `Hash#keys/values` → typed Array; `compact` narrows away nil.
- Tuple: fixed length, per-position types, `[]`/`[]=` → IndexError out of bounds.

## Wrappers

- `Literal.Value(T) { }` → frozen `Literal::Value` subclass: `Age = Literal.Value(_Integer(0..)); Age[42].value`. `==`/`===` by class+value; auto `to_i`/`to_s`/… when T is a known subtype; `delegate :m` macro; Marshal.
- `Literal.Delegator(T) { }` — same but `SimpleDelegator` (forwards all).
- `Literal.Brand(T)` → nominal typing sans wrapper: `Email = Literal.Brand(String); Email === Email.new(s)`. WeakMap-backed; immediates rejected.

## Result

`Literal::Result(S, F)` → generic type; `.success(v)`/`.failure(e)` build checked `Success`/`Failure`; block form `Literal.Result(S, F) { |r| … r.success(v) }` throws for early exit. Instance: `success?` `value!` `error!` `map(T){}` `and_then{}` (bind; failure types union) `also{}` `value_or{}`, pattern matching, exhaustiveness-checked:

```ruby
result.handle do |on|
	on.success(Integer) { |v| }  # union of handled types must cover declared types, else raises
	on.failure { |e| }
end
```

## Serialization (JSON data + JSON Schema)

```ruby
ctx = Literal::SerializationContext.new  # frozen; custom serializers/codecs may be passed first
ctx.serialize(v, type: T)                # → JSON data (strict-checks both sides)
ctx.deserialize(raw, type: T)
ctx.json_schema(T)                       # $defs for recursion
```

First-match over ordered serializer list, shallow `handles_type?`; recursion/cycle legality central (cycles must pass a referenceable node → `$ref`). Custom scalar mapping: subclass `Literal::Serializer::Codec` — `type` (class), `encoded_type` (nullary fixed wire type), `encode(v)`, `decode(raw)`; children handled by encoded type's serializer. Parameterized generics need the full `Literal::Serializer` protocol.

Notables: DataStructures = closed objects via props/`from_props`; enums = backing value; `_Optional` props omitted on write, restored to Undefined on read (never defaulted); untagged unions must be natural (members distinguishable by JSON type or object shape); `_TaggedUnion` writes `"$type"` discriminator (merged into object members, else `{"$type":, "value":}`); non-string-keyed Hashes → arrays of pairs; `description:` → schema.

## Rails

Auto-loads with Rails. AM/AR attribute types `:literal_enum`/`:literal_flags` (`attribute :color, :literal_enum, type: Color`); ActiveJob enum serializer; `ActiveRecord.Relation(Model)` relation type.

## Codebase conventions

Tabs. `case/in`/pattern matching over `is_a?`. Prop/shape names always Symbols — `.name` not `.to_s`. Hot paths compile code strings via `module_eval`. `Literal::ArgumentError`/`Literal::TypeError` < `Literal::Error`. Zeitwerk; Ruby ≥ 3.3; TruffleRuby calls `__after_defined__` manually (no TracePoint).
