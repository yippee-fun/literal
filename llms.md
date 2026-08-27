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
- `_DraftState(T)` — what a draft slot typed T accepts: `_Frozen` relaxed, Properties classes also admit their drafts

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

- `Literal::Coercion { |v| }` — normalizes input; runs only at input boundaries (initializer, writers, draft assignment), never on final-value paths (`from_props`, `marshal_load`). Runs `instance_exec`'d against the object under construction, even when composed.
- `Literal::Seal { |v| }` — fixes final representation (e.g. freeze); runs on every constructing store (initializer, writers, `from_props`) but not `marshal_load` (dump records frozen state, load restores it); must be idempotent, type-preserving. Drafts drop seals until finalize.
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

Canonical per shape: repeated calls return the same class until P's props change (schema-keyed weak cache). Mutable builder mirroring a Properties class: every prop optional (default Undefined), types relaxed to `_DraftState(T)` (`_Deferred` stays lazy — forward refs fine). Coercions pass Undefined/nested drafts through. `draft.finalize(**overrides) { |d| … }` → real instance: overrides assigned through writers, block yielded for last touches, Undefined dropped, nested drafts finalized depth-first (unless the slot wants a draft), then `P.from_props`. Pure — draft not consumed. `DraftClass.build(*args, **kw) { |d| }` = `new` + `finalize`; every DataStructure has `P.build(...)` doing the same from the target class. Draft classes are types matching any draft of a subtype.

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

## Validations — `stipulate` / `.validate`

Author-written invariants beyond what property types already guarantee (`min < max`, "not blank"). `stipulate` is on every `Literal::Properties` class — no mixin. The soft entry points need `from_props`, so they are on `Data`/`Struct`; `Literal::Object` and `Literal::Enum` enforce at construction and answer `#valid?` on an instance, but raise if given props.

```ruby
class Span < Literal::Data
	prop :min, Integer
	prop :max, Integer

	stipulate(:min, "must not be negative") { |min| !min.negative? }
	stipulate(:max, "must be greater than %{min}") { |min, max| max > min }
end
```

**A stipulation is handed values, never the object.** Its predicate's **parameter names** name the properties it reads; it receives their values and returns truthy for pass. So it needs no readers (a shape may declare none), can't call the shape's methods, and reads identically on every path — there is no draft-vs-instance divergence to have. A single anonymous read — `it`, a lone `_1`, or a Symbol proc — reads the property the failure is filed against: `stipulate(:min, "must not be negative") { !it.negative? }`, `stipulate(:count, "must be positive", &:positive?)`. Parameters may be positional or keyword, mixed freely — keyword reads receive their values by name. A property named after a reserved word (`:end`, `:begin`) is only spellable as a keyword, and its value only readable through the binding: `stipulate(:end, "must be after %{begin}") { |begin:, end:| binding.local_variable_get(:end) > binding.local_variable_get(:begin) }`. Beyond that, every parameter must be named and a predicate takes at least one — multiple numbered parameters, `*`/`**`/`&` catch-alls, and zero-parameter predicates (which is what `it` reports on Ruby 3.3, so `it` needs 3.4+) are refused at declaration.

`stipulate(prop, message) { … }` files a failure against `prop` — **one** property, even when the predicate reads several. Drop the symbol (`stipulate(message) { … }`) for a whole-value failure (`prop: nil`). `message` is a String; its `%{name}` slots are filled at failure time with the values the predicate judged: `"must be greater than %{min}"`. A slot may name only a property the stipulation reads, checked at declaration.

The target property, every property read, and the message are all checked **at declaration time**, so a mistake raises where it was written rather than out of every later construction. Names resolve against the properties declared *so far*, so a stipulation reading a property declared below it raises.

A stipulation is handed the caller's own values, given to judge and never to mutate — Ruby cannot enforce that, so a mutating predicate is a bug in the shape's own code, like a raising one. And a property named after a Ruby keyword (`:end`, `:class`) can never be read, since `{ |end| }` will not parse.

**Dependence is derived, never declared.** Stipulations run in declaration order, inherited ones first. Every failure — a type check's, a missing value's, a nested value's own, or another rule's — **taints** the property it is filed against, and a rule that reads a tainted property is **skipped**, so no rule ever judges a value already known bad (and `%{name}` slots only ever splice type-valid values). Independent problems all surface together, even alongside another prop's type failure; a whole-value failure is filed against no property and taints nothing. An unknown key makes *defaults* untrustworthy, never the given values: it may be a typo of a prop that then quietly defaulted, so rules reading a defaulted prop are held back, while rules over explicitly-given values still answer. A duplicated key (two spellings of one name) taints the prop it collided on like any other failure, silencing exactly the rules that read it. A default, coercion or seal that raises after the input was rejected is swallowed (the report already names the cause); on sound input it propagates as it does out of `new`.

**Rules are the invariant, not an advisory pass.** Every path that hands out an object enforces them once each value is assigned and type checked, raising `Literal::ValidationError` (`< StandardError`, `include Literal::Error`) carrying every failure collected: `new`, `[]`, `from_props`, `from`, `from_pack`, `marshal_load`, `build`, `Draft#finalize`, serializer `deserialize`. So **an object that exists satisfies its shape's rules** — which is why the input paths take a nested instance as `new` does, on the strength of its construction. Re-validating an instance (`instance.validate`, `#valid?`) asks whether it holds *now*, so it recurses into nested instances and reports drift inside them with the full path. The error carries `shape` and `errors`, deliberately *not* the offending object; its message renders the full `path`; the backtrace is trimmed to the caller.

Emitted into the generated initializer only when the shape has stipulations, so a shape without them pays nothing. Declaring the first rule re-emits it, so declaration order in the class body doesn't matter and a subclass that adds only a rule still enforces it. An Enum's `stipulate` also checks every already-defined member — members idiomatically sit above the rules, and a member must satisfy them like any other instance. A member's customization block runs before the member registers: the rules re-run on the state the block left, uniqueness is judged on the final value, and a failure registers nothing. (A plain `Data`/`Struct` instance created mid-class-body before `stipulate` is untrackable and stays unchecked.) `stipulate` **refuses once a subclass exists** (as `prop` does) — otherwise the subclass would be less constrained than its parent while still passing as it. `slice` keeps a stipulation only when the property its error is filed against survives *and* every property it reads survives — both, since an error needs somewhere to go — A projection's stipulations are set after its class body ran, so its initializer *and* its writers are re-emitted; a projection that enforced only at construction could be mutated into a state it refuses to be built in.

**Writers enforce too.** A writer runs the stipulations whose outcome **depends on** its property — the ones that *read* it, not the ones filed against it, since where an error goes has no bearing on whether it happens. The prospective value is judged **before it is stored**, so a stipulation that fails — or raises out of its own bug — leaves the object untouched: the write does not half-happen. A property no stipulation reads gets no check emitted, so it costs nothing, and the narrowed stipulation set is precomputed per class. Inherited writers enforce a subclass's stipulations, since the rules are read off the instance's own class at the time of the write. A validated writer returns the written value, as an unvalidated one does.

So an object is valid **always**, not only at construction. Two consequences: a transition that needs two interdependent properties at once cannot go one write at a time — the intermediate state is what the stipulation forbids — so it goes through a draft or `from_props`, which judge the whole value together. And `#valid?` is now only for drift a writer cannot see: a held value mutated in place (`tags.clear`).

### The two soft entry points

Neither raises about the input, and neither constructs an invalid object — the work happens on a `Literal::Draft` and the value is built only once everything holds.

```ruby
Span.validate(min: 1, max: 0)            # same signature as `new`
Span.validate_from_props({"min" => 1})   # untrusted input, Symbol or String keys
```

| | type errors | unknown keys | nested Hash | stipulations |
|---|---|---|---|---|
| `validate(...)` | **raise** (as `new`) | **raise** (`ArgumentError`) | **raise** | collected |
| `draft.validate` / `instance.validate` | collected (drift) | — | — | collected |
| `validate_from_props(hash)` | **collected** | **collected** | **built** | collected |

`validate(...)` forwards to `Draft(self).new(...)`, whose signature matches the initializer's (positionals, splats, block included) and whose writers type check — so it's the form for a caller whose values are already right, asking whether the rules hold. It takes *only* what `new` takes: to validate a draft or instance you already have, ask it (`draft.validate`, `instance.validate`), since accepting one here would be ambiguous for a shape whose first positional property can hold one. `validate_from_props` is the API-body / MCP-argument form. Both answer a `Literal::Result`.

A stipulation reading an undefinable (`prop?`) property that was not given does not apply — `Literal::Undefined` is not a value to judge. A nilable property given nothing holds `nil`, which is, and still is judged.

An instance is re-checked in full, nested instances included (a `Literal::Struct` is mutable; a held value may be mutated in place), and answers *itself* on success. A subclass instance, or a draft of a subclass, validates as its own class. Instances and drafts get `#validate`/`#valid?`. A draft never enforces its drafted type's rules at its own construction — holding them in abeyance is what a draft is for.

Pipeline order mirrors the initializer's: **default → coerce → seal → check**, seals applied exactly once per path. Coercions and defaults run against an instance of the shape carrying the values resolved before them — the receiver `new` gives them — so one that calls the shape's methods or reads an earlier property resolves the same value on every path. Nesting is bounded (64) so untrusted or cyclic input reports rather than exhausting the stack. Two spellings of one key (`:name` and `"name"`) are reported rather than silently collapsed.

### The report

`Literal::Validations::Error` = `prop` (`_Nilable(Symbol)`, the *top-level* property, or the key the caller named for an unknown one), `message`, `path` (`_Array(_Union(Symbol, Integer))`, the full route — fold on it to nest; Integer reserved for future collection indices). `Literal::Validations::Errors` serializes through `SerializationContext` like any Data; `to_h` is shallow, so not JSON-safe on its own.

Messages speak a deliberately small public vocabulary — `"must be a string"`, `"must be an object"`, `"is missing"`, `"is not a known field"`, `"was given more than once"`, `"is nested too deeply"`, `"is not allowed"`. A union never enumerates its members; a `prop?` property is described through the Undefined sentinel, since that member is Literal's, not the author's. A message is written for a value the type check has **already refused**, so it must be total over anything a caller can send: a constrained property is read through `respond_to?` (as `ConstraintType` reads it) and worded only for a unit it knows — `length:` in characters, `size:` in items, either as a range (`"must be between 1 and 3 items"`) or an exact count (`"must be exactly 4 characters"`, `length: 1..` as `"must be filled"`). A constraint it cannot word falls back to the base type rather than inventing wording.

A nested shape is anything that builds from props — `Data` or `Struct` — validated by its own stipulations, with its errors under the property that held it. Reached through exactly the wrappers a draft slot relaxes — `_Nilable`, `_Frozen`, `_Deferred`, and union members (`prop?` included) — in any order, so `draft.validate` agrees with `draft.finalize`. A deferred type materializes rather than reading as no shape at all: naming itself is the only way a shape can be recursive, which is also the only way input can cycle, which is what makes the depth cap load bearing. A Hash for a union reaching **two** shapes gets a plain type failure — which one it meant is not knowable.

Not handled yet: a shape inside `_Array`/`_Hash` gets a plain type failure, not per-item validation. Blocked on `DraftStateType#__relax__` and `Draft#finalize` not recursing into container members; `Error#path` already admits the Integer indices it would need.

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
