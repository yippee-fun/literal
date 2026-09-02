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

## Checks — `check` / `checks`

Author-written invariants beyond what property types already guarantee (`min < max`, "not blank"). Both macros are on every `Literal::Properties` class — no mixin.

```ruby
class Span < Literal::Data
	prop :min, Integer
	prop :max, Integer

	check(:min, "must not be negative") { !it.negative? }
	check(:max, "must be greater than %{min}") { |max, min:| max > min }
	check("must span something") { |min:, max:| min < max }

	checks do |errors, min:, max:|
		errors.add(:max, "must be at least #{min + 1}") unless max > min
		errors.add("must span something") unless min < max
	end
end
```

**A block is handed values, never the object.** Its **keyword parameters name the properties it reads**, so it needs no readers (a shape may declare none), can't call the shape's methods, and reads identically on every path. `check(prop, message) { … }` files one failure against `prop` — **one** property, however many it reads — its block returning truthy for pass; drop the symbol (`check(message) { … }`) for a failure about the value as a whole (`prop: nil`). The message's `%{name}` slots are filled at failure time with the values judged, and may name only a property the check reads. `checks { |errors, …| }` takes a `Literal::Checks::Reporter` first and files its own, interpolating for itself: `errors.add(:max, "…")`, or `errors.add("…")` for the whole value; a name the shape hasn't raises, since nobody could read that error.

The pinned property may be read **positionally**: a bare `it`, a lone `_1`, a Symbol proc (`check(:count, "must be positive", &:positive?)`), or a first positional parameter, which must carry that property's name. Every other read is a keyword — `{ |max, min:| }`, never `{ |max, min| }`. A whole-value `check` has no pinned property, so nothing to read positionally; a `checks` block spends its positional on the reporter and takes at least one keyword. `*`/`**`/`&` catch-alls are refused, as are zero-parameter blocks — which is what a bare `it` reports on Ruby 3.3, so there the block must take a parameter. A property named after a reserved word is only spellable as a keyword, its value only readable through the binding: `check(:end, "must be after %{begin}") { |begin:, end:| binding.local_variable_get(:end) > binding.local_variable_get(:begin) }`.

The pinned property, every read, and the message are checked **at declaration**, against the properties declared *so far* — so a typo, or a read of a property declared below, raises where it was written rather than out of every later construction. A block is given values to judge and never to mutate; Ruby can't enforce that, so a mutating block is a bug in the shape's own code, like a raising one.

**Checks run only after the type pass holds for what they read, and never depend on one another.** A property with a type error is **tainted**, as is one holding a nested value that failed its own checks (a value that failed is no value to hand on); a defaulted property is **phantom** once an unknown key appeared — the key may be a typo of the prop that then quietly defaulted, so an unknown key makes *defaults* untrustworthy while checks over given values still answer. A check reading either is skipped, so none judges a value already known bad and `%{}` only ever splices type-valid values. Everything else runs: one check failing holds no other back, and all failures come back together in declaration order, inherited first. A duplicated key (two spellings of one name) taints the prop it collided on; a whole-value failure taints nothing.

**Checks are the invariant, not an advisory pass.** Every path that hands out an object enforces them, raising `Literal::CheckError` (`< StandardError`, `include Literal::Error`) carrying every failure collected: `new`, `[]`, writers, `from_props`, `from`, `marshal_load`/`from_pack`, serializer `deserialize`, `Draft#finalize`, `build`, Enum member blocks. Type errors raise first, as `Literal::TypeError`, so a check never sees a mistyped value. So **an object that exists satisfies its shape's checks** — which is why the input paths take a nested instance as `new` does, on the strength of its construction. There is no soft path on a built instance.

In the initializer the checks run after every value is assigned, after `after_initialize`, and after the freeze a `Data` appends — so a check judges a finished object and cannot normalize it. Emitted only when the shape has checks, so a shape without them pays nothing; declaring the first re-emits the initializer, so declaration order in the class body doesn't matter and a subclass that adds only a check still enforces it.

**Writers enforce too.** A writer runs the checks that **read** its property — not the ones filed against it, since where an error goes has no bearing on whether it happens — and judges the prospective value **before it is stored**, so a check that fails, or raises out of its own bug, leaves the object untouched: the write does not half-happen. A property no check reads gets no check emitted, and the narrowed set is precomputed per class (`literal_checks_for`). Inherited writers enforce a subclass's checks, read off the instance's own class at the time of the write. So an object is valid **always** — and a transition needing two interdependent properties at once cannot go one write at a time, since the intermediate state is what the check forbids: it goes through a draft or `from_props`, which judge the whole value together.

Declaring a check is **refused** on a frozen class, once a subclass exists (as `prop` is — otherwise the subclass would be less constrained than its parent while still passing as it), and for an Enum whose already-defined members break it (members idiomatically sit above the checks, and a member must satisfy them like any other instance). A member's customization block runs before the member registers: the checks re-run on the state the block left, uniqueness is judged on the final value, and a failure registers nothing. (A plain `Data`/`Struct` instance built mid-class-body before the check is untrackable and stays unchecked.) `slice` keeps a check only when the property it files against survives *and* every property it reads survives — both, since an error needs somewhere to go (a reporting check names its property only as it runs, so one filing against a property the slice dropped raises there — file against what you read); a projection's checks are set after its class body ran, so its initializer *and* its writers are re-emitted. `Klass.literal_checks` / `literal_checks_for(name)` are the readers.

Messages describe the failure, so they read after the property path: `min must not be greater than max`.

### The soft paths

```ruby
Literal::Draft(Span).new(min: 1, max: 0).check   # props already in hand
Literal::Draft(Span).check({"min" => 1})         # untrusted Hash, Symbol or String keys
draft.sound?                                     # the boolean
```

| | type errors | unknown keys | nested Hash | checks |
|---|---|---|---|---|
| `Draft(S).new(...)` | **raise** (its writers type check) | **raise** (`ArgumentError`) | slot takes a draft, not a Hash | held in abeyance |
| `draft.check` / `.sound?` | collected (a slot is laxer than the prop) | — | — | collected |
| `Draft(S).check(hash)` | **collected** | **collected** | **built** | collected |

Both answer `Literal::Result(Span, Literal::Checks::Errors)`, neither mutates the draft, and neither constructs an invalid object — the work happens on the draft and the value is built only once everything holds. `Draft(S).new(...)` mirrors the initializer's signature (positionals, splats, block included) and type checks on assignment, so it's the form for a caller whose values are already right, asking whether the checks hold. `Draft(S).check(hash)` is the API-body / MCP-argument form, where nothing may raise: unknown keys, two spellings of one key, missing values, coercion failures, type errors and nested values are all reported. Nesting is bounded (64) so cyclic or untrusted input reports rather than exhausting the stack, and a draft of a subclass checks as its own class. A draft never enforces its drafted type's checks at its own construction — holding them in abeyance is what a draft is for. Pipeline order mirrors the initializer's: **default → coerce → seal → check**, seals applied exactly once; coercions and defaults run against an instance of the shape carrying the values resolved before them, the receiver `new` gives them. A default, coercion or seal that raises after something was already reported is swallowed (the report already names the cause); on sound input it propagates as it does out of `new`.

A check reading an undefinable (`prop?`) property that was not given does not apply — `Literal::Undefined` is not a value to judge. A nilable property given nothing holds `nil`, which is, and still is judged.

Nested values are checked **depth-first**: the nested shape's own checks run and it is built before the outer checks read it, so a check reads the same finished value on every path; one that failed its checks is never built, and nested failures surface under the property that held it with the full path. A nested shape is anything that builds from props — `Data` or `Struct` — reached through exactly the wrappers a draft slot relaxes (`_Nilable`, `_Frozen`, `_Deferred`, union members, `prop?` included) in any order, so `draft.check` agrees with `draft.finalize`. A deferred type materializes rather than reading as no shape at all: naming itself is the only way a shape can be recursive, which is the only way input can cycle, which is what makes the depth cap load bearing. A Hash for a union reaching **two** shapes gets a plain type failure — which one it meant is not knowable. Not handled yet: a shape inside `_Array`/`_Hash` gets a plain type failure, not per-item checking; `Error#path` already admits the Integer indices it would need.

### The report

`Literal::Checks::Error` = `prop` (`_Nilable(Symbol)`, the *top-level* property, or the key the caller named for an unknown one), `message`, `path` (`_Array(_Union(Symbol, Integer))`, the full route — fold on it to nest). `Literal::Checks::Errors` wraps the list and serializes through `SerializationContext` like any Data; `to_h` is shallow, so not JSON-safe on its own. `Literal::CheckError` carries `shape` and `errors`, deliberately *not* the offending object; its message renders the full `path`, and the backtrace is trimmed to the caller.

Type-failure messages speak a deliberately small public vocabulary — `"must be a string"`, `"must be an object"`, `"is missing"`, `"is not a known field"`, `"was given more than once"`, `"is nested too deeply"`, `"is not allowed"`. A union never enumerates its members; a `prop?` property is described through the Undefined sentinel, since that member is Literal's, not the author's. A message is written for a value the type check has **already refused**, so it must be total over anything a caller can send: a constrained property is read through `respond_to?` (as `ConstraintType` reads it) and worded only for a unit it knows — `length:` in characters, `size:` in items, either as a range (`"must be between 1 and 3 items"`) or an exact count (`"must be exactly 4 characters"`, `length: 1..` as `"must be filled"`). A constraint it cannot word falls back to the base type rather than inventing wording.

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
