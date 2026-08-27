# frozen_string_literal: true

# Covers `stipulate`, `.validate` and `.validate_from_props` on a Literal::Data.
# Rules are the shape's invariant: every construction path enforces them, raising
# Literal::ValidationError. Both entry points are the soft path for those rules:
# they run once the types hold, report every failure rather than the first, and
# answer a Literal::Result carrying the instance or Literal::Validations::Errors.
#
# They differ in the type pass. `.validate` takes what `new` takes and hands it
# to a draft, whose own writers type check, so a wrong value raises there just as
# it would from `new`. `.validate_from_props` takes a Hash of props from outside,
# where nothing may raise, and reports type errors along with everything else.
class Account < Literal::Data
	prop :name, String
	prop :tier, _Nilable(String)

	stipulate(:name, "must not be blank") { |name| !name.strip.empty? }
end

# A nested Data with no rules of its own.
class Address < Literal::Data
	prop :city, String
end

# A shape that names itself, which only a deferred type can express.
class Node < Literal::Data
	prop :n, Integer
	prop :child, _Nilable(_Deferred { Node })

	stipulate(:n, "must be positive") { |n| n > 0 }
end

class Person < Literal::Data
	prop :id, String, description: "The person ID"
	prop :account, Account, description: "The person's account"
	prop :address, _Nilable(Address)
	prop :name, String
	prop :nickname, _Nilable(String)
	prop :role, String, default: -> { "member" }
	prop :tags, _Array(String), default: -> { [] }

	stipulate(:name, "must be between 1 and 10 characters") { |name| (1..10).cover?(name.size) }

	stipulate("name can't be Joe when account is ACME") { |name, account| !(name == "Joe" && account.name == "ACME") }
end

def valid_props(**overrides)
	{ id: "per_1", name: "Ada", account: { name: "Initech" }, **overrides }
end

def errors_for(result)
	result.error!.errors.map { |error| [error.prop, error.message] }
end

# --- success ---

test "returns a Success carrying the built instance" do
	result = Person.validate_from_props(valid_props)

	assert result.success?
	person = result.value!
	assert Person === person
	assert_equal "Ada", person.name
	assert_equal "Initech", person.account.name
end

test "validates a draft of the receiving class" do
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Ada"
	draft.account = Account.new(name: "Initech", tier: nil)

	person = draft.validate.value!

	assert Person === person
	assert_equal "Ada", person.name
	assert_equal "member", person.role
end

test "does not coerce a draft's values again" do
	runs = 0
	counter = -> { runs += 1 }
	klass = Class.new(Literal::Data) do
		prop(:name, String) { |value| counter.call; value.to_s }
	end
	draft = Literal::Draft(klass).new
	draft.name = :Ada

	person = draft.validate.value!

	assert_equal "Ada", person.name
	assert_equal 1, runs
end

test "reports missing props on a draft" do
	draft = Literal::Draft(Person).new
	draft.name = "Ada"
	draft.account = Account.new(name: "Initech", tier: nil)

	assert_equal [[:id, "is missing"]], errors_for(draft.validate)
end

# A draft class is cached against the schema it was made from, so a draft made
# before the shape gained a prop has no slot for it. That reads as unset — a
# report, not a NameError out of the soft path.
test "a draft made before the shape gained a prop reports it as missing" do
	klass = Class.new(Literal::Data) { prop :name, String }
	draft = Literal::Draft(klass).new(name: "Ada")
	klass.prop :age, Integer

	assert_equal [[:age, "is missing"]], errors_for(draft.validate)
end

test "runs validation rules against a draft" do
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Joe"
	draft.account = Account.new(name: "ACME", tier: nil)

	assert_equal [[nil, "name can't be Joe when account is ACME"]], errors_for(draft.validate)
end

test "a draft validates itself through its type" do
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Ada"
	draft.account = Account.new(name: "Initech", tier: nil)

	assert draft.valid?
	assert Person === draft.validate.value!

	draft.name = ""

	refute draft.valid?
	assert_equal [[:name, "must be between 1 and 10 characters"]], errors_for(draft.validate)
end

test "an untyped draft cannot validate" do
	draft = Literal::Draft.new

	assert_raises(Literal::ArgumentError) { draft.validate }
	assert_raises(Literal::ArgumentError) { draft.valid? }
end

# Literal::Draft(T) already matches a draft of any subtype of T, and a subclass
# instance validates as its own class, so a subclass draft does too.
test "validates a draft of a subclass by the subclass" do
	child = Class.new(Account) do
		prop :code, String
		stipulate(:code, "must not be blank") { |code| !code.empty? }
	end

	draft = Literal::Draft(child).new(name: "Initech", code: "")

	assert_equal [[:code, "must not be blank"]], errors_for(draft.validate)

	draft.code = "ACME"
	value = draft.validate.value!

	assert_equal child, value.class
	assert_equal "ACME", value.code
end

# A draft validates through the type it drafts, so it can no longer be handed to
# the wrong shape at all — the mismatch the class-level form had to guard against
# is now unrepresentable.
test "a draft validates as the type it drafts, whatever else it is passed to" do
	draft = Literal::Draft(Account).new
	draft.name = ""

	assert_equal [[:name, "must not be blank"]], errors_for(draft.validate)
	assert_equal Account, draft.validate.success_type
end

test "never mutates a supplied draft" do
	draft = Literal::Draft(Person).new
	draft.name = "Ada"

	draft.validate

	assert_equal "Ada", draft.name
	assert Literal::Undefined == draft.id
	assert Literal::Undefined == draft.tags
end

test "validating never freezes the caller's draft" do
	account = Literal::Draft(Account).new
	account.name = "Initech"
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Ada"
	draft.account = account

	assert draft.validate.success?
	refute draft.frozen?
	refute account.frozen?

	draft.name = "Ida"
	assert draft.validate.success?
end

test "a nested draft on a supplied draft is validated by its own shape" do
	account = Literal::Draft(Account).new
	account.name = ""
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Ada"
	draft.account = account

	result = draft.validate

	assert_equal [[:account, "must not be blank"]], errors_for(result)
	assert_equal %i[account name], result.error!.errors.fetch(0).path
end

test "an incomplete nested draft reports its missing props rather than raising" do
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Ada"
	draft.account = Literal::Draft(Account).new

	result = draft.validate

	assert_equal [[:account, "is missing"]], errors_for(result)
	assert_equal %i[account name], result.error!.errors.fetch(0).path
end

# A shape with no rules of its own reports the same way as one with them:
# nested validation is not conditional on having rules.
test "an incomplete nested draft of a shape with no rules names the missing field" do
	outer = Class.new(Literal::Data) do
		prop :address, Address
	end
	draft = Literal::Draft(outer).new
	draft.address = Literal::Draft(Address).new

	result = draft.validate

	assert_equal [[:address, "is missing"]], result.error!.errors.map { |error| [error.prop, error.message] }
	assert_equal %i[address city], result.error!.errors.fetch(0).path
end

test "applies prop defaults for props that were not given" do
	person = Person.validate_from_props(valid_props).value!

	assert_equal "member", person.role
	assert_equal [], person.tags
end

test "leaves a nilable prop nil rather than treating it as missing" do
	assert Person.validate_from_props(valid_props).value!.nickname.nil?
end

# `new` refuses an unknown keyword and `from_props` an unknown attribute, so a
# key the shape has no prop for is reported, not dropped. A mistyped field that
# vanished would read as one the caller never sent.
test "reports a key that is not a prop" do
	result = Person.validate_from_props(valid_props(surprise: "unexpected"))

	assert_equal [[:surprise, "is not a known field"]], errors_for(result)
	assert_equal [:surprise], result.error!.errors.fetch(0).path
end

test "reports every unknown key, not just the first" do
	result = Person.validate_from_props(valid_props(surprise: 1, shock: 2))

	assert_equal %i[surprise shock], result.error!.errors.map(&:prop)
end

test "an unknown key is reported alongside the props that are wrong" do
	result = Person.validate_from_props(valid_props(id: 1, surprise: "unexpected"))

	assert_equal [[:surprise, "is not a known field"], [:id, "must be a string"]], errors_for(result)
end

# An unknown key means this shape did not understand the input, so the rules
# have nothing trustworthy to read.
test "an unknown key holds the stipulations back" do
	ran = false
	klass = Class.new(Literal::Data) do
		prop :name, String
	end
	klass.stipulate(:name, "never reported") { |name| ran = true }

	assert klass.validate_from_props(name: "Ada", surprise: 1).failure?
	refute ran
end

test "a string key that names no prop is reported as the symbol it interns to" do
	result = Person.validate_from_props({ "surprise" => 1, **valid_props })

	assert_equal [[:surprise, "is not a known field"]], errors_for(result)
end

# `:name` and `"name"` collapse when String keys are interned, and which value
# survives depends on the order they were given in — a good value could vanish
# and pass, or vanish and be reported against. Neither is safe to pick, so the
# pair is reported and neither value is judged.
test "a key given in both spellings is reported as a duplicate" do
	result = Person.validate_from_props({ "name" => "Ada", **valid_props(name: "Ada") })

	assert result.failure?
	assert_includes errors_for(result), [:name, "was given more than once"]
end

test "a duplicated key's values are not judged" do
	result = Person.validate_from_props({ "name" => 42, **valid_props(name: "Ada") })

	assert_equal [[:name, "was given more than once"]], errors_for(result)
end

test "a duplicated key holds the stipulations back" do
	ran = false
	klass = Class.new(Literal::Data) do
		prop :name, String
	end
	klass.stipulate(:name, "never reported") { |name| ran = true }

	assert klass.validate_from_props({ "name" => "Ada", :name => "Ada" }).failure?
	refute ran
end

# --- input guarding ---

test "input that is not a hash, draft, or instance raises" do
	[nil, "junk", 42, [1, 2]].each do |input|
		error = assert_raises(Literal::ArgumentError) { Person.validate_from_props(input) }

		assert error.message.include?(input.class.name)
	end
end

# A key that is neither Symbol nor String cannot go in `prop`, so it is filed
# against the value as a whole and the message names it.
test "a key that cannot name a prop is reported against no prop" do
	result = Person.validate_from_props({ 1 => "x", **valid_props })

	assert_equal [[nil, "1 is not a known field"]], errors_for(result)
	assert_equal [], result.error!.errors.fetch(0).path
end

test "a key that cannot name a prop is reported inside a nested Hash too" do
	result = Person.validate_from_props(valid_props(account: { 1 => "x", "name" => "Initech" }))

	assert_equal [[:account, "1 is not a known field"]], errors_for(result)
	assert_equal [:account], result.error!.errors.fetch(0).path
end

# --- instances ---

test "an object validates itself by its own rules" do
	person = Person.new(id: "per_1", name: "Ada", account: Account.new(name: "Initech"))

	assert person.valid?
	assert Person === person.validate.value!
end

# A writer enforces the stipulations its property is part of, so this drift
# cannot happen — and the write does not half-happen either.
test "a writer refuses a value that breaks a stipulation, and leaves the old one" do
	klass = Class.new(Literal::Struct) do
		prop :name, String
		stipulate(:name, "must be filled") { |name| !name.empty? }
	end
	object = klass.new(name: "Ada")

	assert_raises(Literal::ValidationError) { object.name = "" }
	assert_equal "Ada", object.name
	assert object.valid?
end

# What a writer cannot see is a held value mutated in place, which is the drift
# `#valid?` is still for.
test "a value mutated in place is drift a writer cannot catch" do
	klass = Class.new(Literal::Struct) do
		prop :tags, _Array(String)
		stipulate(:tags, "must not be empty") { |tags| !tags.empty? }
	end
	object = klass.new(tags: ["a"])

	assert object.valid?

	object.tags.clear

	refute object.valid?
	assert_equal [[:tags, "must not be empty"]], errors_for(object.validate)
end

test "an object whose held value was mutated in place reports the type" do
	klass = Class.new(Literal::Struct) do
		prop :tags, _Array(String)
	end
	object = klass.new(tags: ["ok"])
	object.tags << 42

	refute object.valid?
	assert_equal [[:tags, "must be an array where each member is a string"]], errors_for(object.validate)
end

# Re-validating an instance asks whether it holds now, so drift inside a nested
# instance is its business too — construction proved the child valid then, not
# forever.
test "an instance reports drift inside a nested instance" do
	child_class = Class.new(Literal::Struct) do
		prop :tags, _Array(String), reader: :public
		stipulate(:tags, "must not be empty") { |tags| !tags.empty? }
	end
	parent_class = Class.new(Literal::Struct) do
		prop :child, child_class
	end
	child = child_class.new(tags: ["a"])
	parent = parent_class.new(child:)

	assert parent.valid?

	child.tags.clear

	refute parent.valid?
	assert_equal [[[:child, :tags], "must not be empty"]], parent.validate.error!.errors.map { |error| [error.path, error.message] }
end

# The input paths still trust a built instance, since `new` does, and validate
# accepts exactly what `new` accepts.
test "validate_from_props takes a drifted instance as new would" do
	child_class = Class.new(Literal::Struct) do
		prop :tags, _Array(String), reader: :public
		stipulate(:tags, "must not be empty") { |tags| !tags.empty? }
	end
	parent_class = Class.new(Literal::Struct) do
		prop :child, child_class
	end
	child = child_class.new(tags: ["a"])
	child.tags.clear

	assert parent_class.new(child:)
	assert parent_class.validate_from_props(child:).success?
end

test "a valid object answers itself, not a copy" do
	person = Person.new(id: "per_1", name: "Ada", account: Account.new(name: "Initech"))

	assert person.validate.value!.equal?(person)
end

test "a valid nested instance stays the same object" do
	account = Account.new(name: "Initech")

	person = Person.validate(**valid_props(account:)).value!

	assert person.account.equal?(account)
end

# An inherited writer enforces the subclass's stipulations too, because it reads
# `stipulations` off the instance's own class at the time of the write.
test "an inherited writer enforces the subclass's stipulations" do
	base = Class.new(Literal::Struct) do
		prop :name, String
		stipulate(:name, "base says blank") { |name| !name.empty? }
	end
	sub = Class.new(base) do
		stipulate(:name, "sub says short") { |name| name.size >= 3 }
	end

	instance = sub.new(name: "Ada")

	error = assert_raises(Literal::ValidationError) { instance.name = "Jo" }

	assert_equal ["sub says short"], error.errors.errors.map(&:message)
	assert_equal "Ada", instance.name

	# The parent is unaffected by its subclass's stipulation.
	assert_equal "Jo", base.new(name: "Ada").tap { |value| value.name = "Jo" }.name
end

# --- shape context for coercions and defaults ---

test "a coercion may call the shape's own methods" do
	klass = Class.new(Literal::Data) do
		prop(:name, String) { |value| presentable(value) }

		private def presentable(value) = value.to_s.strip
	end

	assert_equal "Ada", klass.validate(name: " Ada ").value!.name
end

test "a default may call the shape's own methods" do
	klass = Class.new(Literal::Data) do
		prop :role, String, default: -> { default_role }

		private def default_role = "member"
	end

	assert_equal "member", klass.validate.value!.role
end

# The receiver carries the properties assigned before this one, exactly as it
# does in the generated initializer — so a coercion that reads a sibling
# resolves the same value on every path.
test "a coercion reading an earlier property agrees with new" do
	klass = Class.new(Literal::Struct) do
		prop :currency, String
		prop :amount, Integer do |value|
			(String === currency) ? Integer(value) : Integer(value) * 2
		end
	end

	assert_equal 5, klass.new(currency: "GBP", amount: "5").amount
	assert_equal 5, klass.validate(currency: "GBP", amount: "5").value!.amount
	assert_equal 5, klass.validate_from_props({ "currency" => "GBP", "amount" => "5" }).value!.amount
end

test "a default reading an earlier property agrees with new" do
	klass = Class.new(Literal::Data) do
		prop :name, String, reader: :public
		prop :email, String, default: -> { "#{name.downcase}@corp.com" }
	end

	assert_equal "ada@corp.com", klass.new(name: "Ada").email
	assert_equal "ada@corp.com", klass.validate_from_props({ name: "Ada" }).value!.email
end

# Once the input is rejected, the shape's own code runs against values it was
# never promised — a default reading a rejected sibling gets nil where
# construction guarantees a value. The raise is the input's fault and the
# report already names it, so it is not a second failure.
test "a default reading a rejected sibling reports the sibling, not a raise" do
	klass = Class.new(Literal::Data) do
		prop :name, String, reader: :public
		prop :email, String, default: -> { "#{name.downcase}@corp.com" }
	end

	assert_equal [[:name, "must be a string"]], errors_for(klass.validate_from_props({ name: 42 }))
end

# On sound input, the same raise is the shape's own bug, and it propagates
# exactly as it does out of new.
test "a default that raises on sound input still raises" do
	klass = Class.new(Literal::Data) do
		prop :email, String, default: -> { raise "broken default" }
	end

	error = assert_raises(RuntimeError) { klass.validate_from_props({}) }

	assert_equal "broken default", error.message
end

# The context is per draft: validating works on a copy, and that copy must not
# write resolved defaults onto an object the caller's draft still shares.
test "validating a draft leaves its context untouched" do
	klass = Class.new(Literal::Data) do
		prop :sku, String
		prop :qty, Integer, default: -> { 7 }
	end
	draft = Literal::Draft(klass).new(sku: "x")
	context = draft.__context__

	assert draft.valid?
	refute context.instance_variable_defined?(:@qty)
end

# Both copy paths, since clone does not go through initialize_dup.
test "a duped or cloned draft gets its own context" do
	klass = Class.new(Literal::Data) do
		prop :sku, String
	end
	draft = Literal::Draft(klass).new(sku: "x")
	context = draft.__context__

	refute draft.dup.__context__.equal?(context)
	refute draft.clone.__context__.equal?(context)
end

# A slot reset to Undefined is unset again, and the receiver must say so — a
# coercion reading it gets what a fresh construction would give it.
test "a coercion sees a sibling reset to Undefined as unset" do
	klass = Class.new(Literal::Struct) do
		prop :name, _Nilable(String), reader: :public
		prop :email, String do |value|
			name ? "#{value}@#{name.downcase}" : value.to_s
		end
	end

	draft = Literal::Draft(klass).new
	draft[:name] = "Ada"
	draft[:name] = Literal::Undefined
	draft[:email] = "a"

	assert_equal "a", draft[:email]
end

# --- the two entry points ---

# A wrong type is the difference between them: `validate` puts its arguments on a
# draft, and a draft's writers check, so it raises exactly where `new` does.
test "validate raises a wrong type, where validate_from_props reports it" do
	assert_raises(Literal::TypeError) { Person.new(**valid_props(name: 123)) }
	assert_raises(Literal::TypeError) do
		Person.validate(id: "per_1", name: 123, account: Account.new(name: "Initech"))
	end

	assert_equal [[:name, "must be a string"]], errors_for(Person.validate_from_props(valid_props(name: 123)))
end

# The draft's initializer has the shape's own signature, so a key that names no
# prop is an unknown keyword rather than a field to report.
test "validate raises an unknown keyword, where validate_from_props reports it" do
	assert_raises(ArgumentError) do
		Person.validate(id: "per_1", name: "Ada", account: Account.new(name: "Initech"), surprise: 1)
	end

	assert_equal [[:surprise, "is not a known field"]], errors_for(Person.validate_from_props(valid_props(surprise: 1)))
end

# A draft slot holds a built value or a nested draft, never a Hash, so building a
# nested shape from one is the props form's leniency and not the draft's.
test "validate raises a nested Hash, where validate_from_props builds it" do
	assert_raises(Literal::TypeError) do
		Person.validate(id: "per_1", name: "Ada", account: { name: "Initech" })
	end

	assert_equal "Initech", Person.validate_from_props(valid_props).value!.account.name
end

# Only the type pass belongs to the draft. The rules are what either form is for,
# so a rule failure is still collected rather than raised.
test "validate collects a stipulation failure rather than raising it" do
	result = Person.validate(id: "per_1", name: "Bartholomew", account: Account.new(name: "Initech"))

	assert_equal [[:name, "must be between 1 and 10 characters"]], errors_for(result)
end

# The same signature as `new`, not a Hash of props: a positional prop, a splat and
# a block prop all reach the draft the way they reach the initializer.
test "validate takes the arguments new takes" do
	klass = Class.new(Literal::Data) do
		prop :first, String, :positional
		prop :rest, _Array(String), :*
		prop :handler, _Nilable(Proc), :&
	end

	# One Proc for both calls, so the two values compare equal rather than
	# differing by which block object each captured.
	handler = -> (value) { value }

	built = klass.new("a", "b", "c", &handler)
	validated = klass.validate("a", "b", "c", &handler).value!

	assert_equal built, validated
	assert_equal "a", validated.first
	assert_equal ["b", "c"], validated.rest
	assert_equal handler, validated.handler
	assert Proc === klass.validate("a") { |value| value }.value!.handler
end

# --- type pass ---

test "reports every bad prop, not just the first" do
	result = Person.validate_from_props(id: 1, name: 2, account: { name: "Initech" })

	assert result.failure?
	assert_equal [[:id, "must be a string"], [:name, "must be a string"]], errors_for(result).sort
end

test "reports a missing required prop" do
	result = Person.validate_from_props(name: "Ada", account: { name: "Initech" })

	assert_equal [[:id, "is missing"]], errors_for(result)
end

test "does not require a prop that has a default or is nilable" do
	assert Person.validate_from_props(valid_props).success?
end

# `new` collects a splat into an empty Array or Hash rather than treating it as
# missing, so validate resolves it the same way. `Property#default?` answers
# true for a splat while its `default` is nil, so it cannot go through the
# defaulting branch.
test "resolves an omitted splat the way new does" do
	klass = Class.new(Literal::Data) do
		prop :first, String
		prop :rest, _Array(String), :*
		prop :opts, _Hash(Symbol, String), :**
	end

	value = klass.validate(first: "a").value!

	assert_equal [], value.rest
	assert_equal({}, value.opts)
end

test "a splat resolves the same way from a draft and from an instance" do
	klass = Class.new(Literal::Data) do
		prop :first, String
		prop :rest, _Array(String), :*
	end

	assert_equal [], Literal::Draft(klass).new(first: "a").validate.value!.rest
	assert_equal [], klass.new(first: "a").validate.value!.rest
end

test "describes a nilable prop by what it must be, not by its nilability" do
	result = Person.validate_from_props(valid_props(nickname: 42))

	assert_equal [[:nickname, "must be a string"]], errors_for(result)
end

# A coercion block runs on assignment, so the raw value is not what gets checked.
test "a coercing prop coerces a raw value that does not fit" do
	klass = Class.new(Literal::Data) do
		prop(:limit, Integer) { |v| (String === v) ? (Integer(v, exception: false) || v) : v }
	end

	assert_equal 25, klass.validate(limit: "25").value!.limit
	assert_equal 25, klass.validate(limit: 25).value!.limit
end

test "a coercing prop whose value will not coerce is reported" do
	klass = Class.new(Literal::Data) do
		prop(:limit, Integer) { |v| (String === v) ? (Integer(v, exception: false) || v) : v }
	end

	result = klass.validate_from_props(limit: "abc")

	assert_equal [[:limit, "must be an integer"]], result.error!.errors.map { |error| [error.prop, error.message] }
end

test "a coercion that raises reads as a type failure on its prop" do
	klass = Class.new(Literal::Data) do
		prop(:limit, Integer) { |v| Integer(v) }
	end

	assert_equal [[:limit, "must be an integer"]], klass.validate_from_props(limit: "abc").error!.errors.map { |error| [error.prop, error.message] }
	assert_equal 25, klass.validate(limit: "25").value!.limit
end

# The message has to describe whatever failed the type. Describing the raw value
# instead lets a coercion that returns the wrong type contradict itself — a value
# inside the range told it must be in the range.
test "a coercion that returns the wrong type is described by what it returned" do
	klass = Class.new(Literal::Data) do
		prop(:n, _Integer(1..10), &:to_s)
	end

	assert_equal [[:n, "must be an integer"]], errors_for(klass.validate_from_props(n: 5))
end

test "a coerced value that misses a constraint is described by the constraint" do
	klass = Class.new(Literal::Data) do
		prop(:n, _Integer(1..10)) { |value| Integer(value) }
	end

	assert_equal [[:n, "must be between 1 and 10"]], errors_for(klass.validate_from_props(n: "500"))
end

test "a coercion runs once" do
	runs = 0
	counter = -> { runs += 1 }
	klass = Class.new(Literal::Data) do
		prop(:name, String) { |v| counter.call; v.to_s }
	end

	klass.validate(name: :ada)

	assert_equal 1, runs
end

test "describes an array prop by its member type" do
	result = Person.validate_from_props(valid_props(tags: "nope"))

	assert_equal [[:tags, "must be an array"]], errors_for(result)
end

test "an array with a bad member is told what each member must be" do
	result = Person.validate_from_props(valid_props(tags: ["ok", 42]))

	assert_equal [[:tags, "must be an array where each member is a string"]], errors_for(result)
end

# --- message wording ---

# Each expectation is a string a caller reads, so changing one changes the
# contract.
class Constrained < Literal::Data
	prop :limit, _Integer(1..100), default: -> { 10 }
	prop :page, _Integer(1..), default: -> { 1 }
	prop :share, _Integer(..100), default: -> { 1 }
	prop :name, _String(length: 1..), default: -> { "x" }
	prop :code, _String(length: 2..10), default: -> { "ab" }
	prop :slug, _String(/\A[a-z]+\z/), default: -> { "ok" }
	prop :pin, _String(length: 4), default: -> { "0000" }
	prop :initial, _String(length: 1), default: -> { "a" }
	prop :items, _Constraint(Array, size: 1..3), default: -> { [1] }
	prop :anything, _Constraint(length: 1..), default: -> { "x" }
	prop :kind, _Union("employee", "contractor", "vendor"), default: -> { "employee" }
	prop :active, _Boolean, default: -> { true }
	prop :either, _Union(String, Integer), default: -> { "x" }

	# Every one of these values is wrong for its prop, so they come in as props
	# from outside rather than as arguments a draft would refuse.
	def self.message(**props)
		validate_from_props(props).error!.errors.fetch(0).message
	end
end

test "a bounded range reads as the bounds" do
	assert_equal "must be between 1 and 100", Constrained.message(limit: 500)
end

test "a half-open range reads as one bound" do
	assert_equal "must be at least 1", Constrained.message(page: 0)
	assert_equal "must be at most 100", Constrained.message(share: 200)
end

test "a wrong-typed value is told its type, not the constraint it also broke" do
	assert_equal "must be an integer", Constrained.message(limit: "25")
	assert_equal "must be a string", Constrained.message(name: 42)
end

test "length 1.. is how a prop spells filled, and says so" do
	assert_equal "must be filled", Constrained.message(name: "")
end

test "a length range reads in characters" do
	assert_equal "must be between 2 and 10 characters", Constrained.message(code: "a")
end

# A constrained property takes any matcher, not only a Range, so a message has to
# word an exact count too rather than reaching for bounds it hasn't got.
test "an exact length reads as exactly that many" do
	assert_equal "must be exactly 4 characters", Constrained.message(pin: "12")
	assert_equal "must be exactly 1 character", Constrained.message(initial: "ab")
end

# A count of something that isn't characters reads in its own units, or a value
# that is an array would be told it must be an array.
test "a size range reads in items" do
	assert_equal "must be between 1 and 3 items", Constrained.message(items: [])
end

# The type check reads a constrained property through respond_to? and answers
# false for a value that cannot answer at all. A message is written for input the
# type check has already refused, so it has to survive the same values.
test "a value that cannot answer a constrained property is told what was wanted" do
	assert_equal "must be filled", Constrained.message(anything: Object.new)
end

test "a pattern reads as a format" do
	assert_equal "must be a string in the expected format", Constrained.message(slug: "NOPE")
end

# A union's members may be internal — an allowlist, a set of private shapes —
# so the message never names or enumerates them.
test "a union reads as not allowed, without enumerating its members" do
	assert_equal "is not allowed", Constrained.message(kind: "nope")
	assert_equal "is not allowed", Constrained.message(either: 1.5)
end

test "a boolean reads as a boolean" do
	assert_equal "must be a boolean", Constrained.message(active: "yes")
end

# Wrappers that fix representation or omittability say nothing about what the
# value must be, so the wording comes from what they wrap — the same way the
# equivalent unwrapped prop reads.
test "a frozen type reads as what it wraps" do
	klass = Class.new(Literal::Data) do
		prop :name, _Frozen(String), &Literal.Seal { |value| value.frozen? ? value : value.dup.freeze }
	end

	assert_equal [[:name, "must be a string"]], errors_for(klass.validate_from_props(name: 42))
end

test "an optional nilable prop reads as what it wraps" do
	klass = Class.new(Literal::Data) do
		prop? :nickname, _Nilable(String)
	end

	assert_equal [[:nickname, "must be a string"]], errors_for(klass.validate_from_props(nickname: 42))
end

# --- pass 1 failing is the whole answer ---

# A stipulation is handed values, so it only ever runs against a draft where
# every prop holds one.
test "a type failure returns without running a stipulation" do
	ran = false
	klass = Class.new(Literal::Data) do
		prop :name, String
		stipulate(:name, "never reported") { |name| ran = true }
	end

	assert klass.validate_from_props(name: 1).failure?
	refute ran
end

test "a missing required prop returns without running a stipulation" do
	ran = false
	klass = Class.new(Literal::Data) do
		prop :a, String
		stipulate(:a, "never reported") { |a| ran = true }
	end

	result = klass.validate_from_props({})

	assert_equal [[:a, "is missing"]], result.error!.errors.map { |error| [error.prop, error.message] }
	refute ran
end

test "a bad prop silences only the rules that read it" do
	bad = Person.validate_from_props(id: 1, name: "Bartholomew", account: { name: "Initech" })
	assert_equal [[:id, "must be a string"], [:name, "must be between 1 and 10 characters"]], errors_for(bad)

	good = Person.validate_from_props(id: "per_1", name: "Bartholomew", account: { name: "Initech" })
	assert_equal [[:name, "must be between 1 and 10 characters"]], errors_for(good)
end

test "a stipulation reads an omitted nilable prop as the nil the object will hold" do
	seen = :never_ran
	klass = Class.new(Literal::Data) do
		prop :name, String
		prop :nickname, _Nilable(String)
		stipulate(:nickname, "never reported") { |nickname| seen = nickname; true }
	end

	assert klass.validate(name: "Ada").success?
	assert seen.nil?
end

# A failure taints the property it is filed against, and a rule reading a
# tainted property is skipped — including a whole-value rule.
test "the first failure on a property silences later rules reading it" do
	klass = Class.new(Literal::Data) do
		prop :name, String

		stipulate(:name, "one") { |name| false }
		stipulate(:name, "two") { |name| false }
		stipulate("three") { |name| false }
	end

	errors = klass.validate(name: "Ada").error!.errors.map { |error| [error.prop, error.message] }

	assert_equal [[:name, "one"]], errors
end

# A failure taints the property it is filed against, not the ones it read —
# so a rule reading the target of an earlier failure is skipped even when the
# two rules read disjoint values.
test "a rule's failure taints its target for the rules after it" do
	seen = :never
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		stipulate(:max, "must be greater than %{min}") { |min, max| max > min }
		stipulate(:max, "never reported") { |max| seen = max; false }
	end

	assert_equal [[:max, "must be greater than 5"]], errors_for(klass.validate(min: 5, max: 1))
	assert_equal :never, seen
end

# Writers judge with the same taints: a rule whose premise another rule just
# failed is skipped there too.
test "a writer skips the rules whose premise failed" do
	seen = :never
	klass = Class.new(Literal::Struct) do
		prop :min, Integer
		prop :max, Integer

		stipulate(:max, "must be greater than %{min}") { |min, max| max > min }
		stipulate(:max, "never reported for 10") { |min, max| seen = [min, max]; min != 10 }
	end
	object = klass.new(min: 1, max: 5)
	seen = :never

	error = assert_raises(Literal::ValidationError) { object.min = 10 }

	assert_equal ["must be greater than 10"], error.errors.errors.map(&:message)
	assert_equal :never, seen
	assert_equal 1, object.min
end

# A whole-value failure is filed against no property, so it taints nothing —
# the rules after it run as though it had passed.
test "a whole-value failure does not silence anything" do
	klass = Class.new(Literal::Data) do
		prop :name, String

		stipulate("one") { |name| false }
		stipulate(:name, "two") { |name| false }
	end

	errors = klass.validate(name: "Ada").error!.errors.map { |error| [error.prop, error.message] }

	assert_equal [[nil, "one"], [:name, "two"]], errors
end

# A rule's failure taints its target, so a later rule reading it is skipped —
# a rule may read a property plainly instead of re-checking what an earlier
# one already rejected.
test "a rule that reports silences the readers of its target" do
	order = []
	klass = Class.new(Literal::Data) do
		prop :name, String

		stipulate(:name, "one") { |name| order << :first; false }
		stipulate(:name, "two") { |name| order << :second; false }
	end

	errors = klass.validate(name: "Ada").error!.errors.map(&:message)

	assert_equal [:first], order
	assert_equal ["one"], errors
end

test "stipulations run in declaration order while each of them passes" do
	order = []
	klass = Class.new(Literal::Data) do
		prop :name, String

		stipulate(:name, "one") { |name| order << :first }
		stipulate(:name, "two") { |name| order << :second }
		stipulate(:name, "three") { |name| order << :third; false }
	end

	assert_equal ["three"], klass.validate(name: "Ada").error!.errors.map(&:message)
	assert_equal %i[first second third], order
end

test "construction skips tainted readers the same way" do
	klass = Class.new(Literal::Data) do
		prop :name, String

		stipulate(:name, "one") { |name| false }
		stipulate(:name, "two") { |name| false }
	end

	error = assert_raises(Literal::ValidationError) { klass.new(name: "Ada") }

	assert_equal ["one"], error.errors.errors.map(&:message)
end

test "a failure carries validation errors" do
	errors = Person.validate_from_props(valid_props(id: 1)).error!

	assert Literal::Validations::Errors === errors
	assert_equal [[:id, "must be a string"]], errors.errors.map { |error| [error.prop, error.message] }
end

# --- rules pass ---

test "runs a single-prop rule against the built value" do
	result = Person.validate_from_props(valid_props(name: "Bartholomew"))

	assert_equal [[:name, "must be between 1 and 10 characters"]], errors_for(result)
end

test "an error about the whole value is filed with no prop" do
	result = Person.validate_from_props(valid_props(name: "Joe", account: { name: "ACME" }))

	assert_equal [[nil, "name can't be Joe when account is ACME"]], errors_for(result)
end

test "a dependent rule runs once the ones it depends on pass" do
	klass = Class.new(Literal::Data) do
		prop :name, String

		stipulate(:name, "must be filled") { |name| !name.empty? }
		stipulate("must not be Jo") { |name| name != "Jo" }
	end

	assert_equal [[:name, "must be filled"]], errors_for(klass.validate(name: ""))
	assert_equal [[nil, "must not be Jo"]], errors_for(klass.validate(name: "Jo"))
	assert klass.validate(name: "Ada").success?
end

# --- what a stipulation reads ---

# A stipulation names the properties it reads by its parameter names, and is
# handed their values — never the object — so it asks nothing of the shape.
test "a predicate is handed the values of the properties it names" do
	seen = nil
	klass = Class.new(Literal::Data) do
		prop :name, String
		prop :age, Integer
		stipulate(:name, "never reported") { |name, age| seen = [name, age]; true }
	end

	assert klass.validate(name: "Ada", age: 36).success?
	assert_equal ["Ada", 36], seen
end

# The single-property case needs no name at all: an unnamed parameter — what `it`
# gives — reads the property the failure is reported against.
test "it reads the property the error is reported against" do
	klass = Class.new(Literal::Data) do
		prop :name, String
		prop :age, Integer
		stipulate(:age, "must be an adult") { |age| age >= 18 }
	end

	assert_equal [[:age, "must be an adult"]], errors_for(klass.validate(name: "Ada", age: 12))
	assert klass.validate(name: "Ada", age: 18).success?
end

# A predicate may read more than one property while the failure is still
# reported against the one the caller should fix.
test "a predicate reads two properties and reports against one" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		stipulate(:max, "must be greater than min") { |min, max| max > min }
	end

	assert_equal [[:max, "must be greater than min"]], errors_for(klass.validate(min: 5, max: 1))
	assert klass.validate(min: 1, max: 5).success?
end

# A message's %{name} slots are filled with the values the predicate judged, so
# a message can name what it saw.
test "a message interpolates the values the predicate judged" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		stipulate(:max, "must be greater than %{min}") { |min, max| max > min }
	end

	assert_equal [[:max, "must be greater than 5"]], errors_for(klass.validate(min: 5, max: 1))
end

test "a whole-value message interpolates too" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		stipulate("%{min} to %{max} is not a span") { |min, max| max > min }
	end

	assert_equal [[nil, "5 to 1 is not a span"]], errors_for(klass.validate(min: 5, max: 1))
end

# Only %{name} is a slot: a literal percent sign — "100%", "% off" — passes
# through untouched, unlike format-string interpolation.
test "a message without slots keeps its percent signs" do
	klass = Class.new(Literal::Data) do
		prop :rate, Integer
		stipulate(:rate, "must be under 100%") { |rate| rate < 100 }
	end

	assert_equal [[:rate, "must be under 100%"]], errors_for(klass.validate(rate: 150))
end

# A slot names a property, and property names are not confined to ASCII.
test "a slot fills a non-ASCII property name" do
	klass = Class.new(Literal::Data) do
		prop :größe, Integer
		stipulate(:größe, "%{größe} is too big") { |größe| größe < 10 }
	end

	assert_equal [[:größe, "42 is too big"]], errors_for(klass.validate(:größe => 42))
end

# A value's to_s is spliced in verbatim — gsub's replacement conventions do not
# apply to it, and a value that happens to contain a slot is not re-expanded.
test "an interpolated value is not itself interpreted" do
	klass = Class.new(Literal::Data) do
		prop :name, String
		stipulate(:name, "%{name} is reserved") { |name| name != "\\1 %{name}" }
	end

	assert_equal [[:name, "\\1 %{name} is reserved"]], errors_for(klass.validate(name: "\\1 %{name}"))
end

# The message is checked once, at declaration — so the stipulation keeps its own
# copy, or the caller could mutate an unfillable slot in after the check.
test "a message mutated after declaration keeps its checked form" do
	message = +"must be positive"

	klass = Class.new(Literal::Data) do
		prop :count, Integer
		stipulate(:count, message) { |count| count > 0 }
	end

	message << " (max %{max})"

	assert_equal [[:count, "must be positive"]], errors_for(klass.validate(count: -1))
end

# The parameter names are the shape's own property names, so a name it does not
# have is a mistake in the stipulation, not a validation failure. It is caught
# where it is written rather than on the first value that reaches it.
test "naming a property the shape does not have raises at declaration time" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			stipulate(:name, "…") { |nope| nope }
		end
	end

	assert(/nope/.match?(error.message))
end

# Values are read out of storage, so a stipulation works on a shape that declares
# no readers at all.
test "a shape with no readers still validates" do
	klass = Class.new(Literal::Data) do
		prop :name, String, reader: false
		prop :age, Integer, reader: false
		stipulate(:age, "must be an adult") { |name, age| name.empty? || age >= 18 }
	end

	refute klass.new(name: "Ada", age: 36).respond_to?(:name)
	assert_equal [[:age, "must be an adult"]], errors_for(klass.validate(name: "Ada", age: 12))
end

test "a stipulation reads a defaulted prop as the value the object will carry" do
	klass = Class.new(Literal::Data) do
		prop :limit, Integer, default: -> { 10 }
		stipulate(:limit, "saw %{limit}") { |limit| limit < 5 }
	end

	assert_equal [[:limit, "saw 10"]], klass.validate.error!.errors.map { |error| [error.prop, error.message] }
end

# `validate_from_props` mirrors `from_props`: one Hash of property values, so a
# caller holding untrusted input has nothing to splat. It declares no keywords of
# its own, so keywords written at the call site arrive as that Hash.
test "takes the props as a Hash, written as one or as keywords" do
	props = { id: "per_1", name: "Ada", account: { name: "Initech" } }

	assert Person.validate_from_props(props).success?
	assert Person.validate_from_props(id: "per_1", name: "Ada", account: { name: "Initech" }).success?
end

test "takes no arguments at all when every prop can default" do
	klass = Class.new(Literal::Data) do
		prop :role, String, default: -> { "member" }
	end

	assert_equal "member", klass.validate.value!.role
end

test "uses the current prop shape after the class changes" do
	klass = Class.new(Literal::Data) do
		prop :name, String
	end

	assert klass.validate(name: "Ada").success?

	klass.prop :age, Integer

	person = klass.validate(name: "Ada", age: 42).value!
	assert_equal 42, person.age
end

# --- nested ---

test "validates a Hash for a Data prop with that type's own rules" do
	result = Person.validate_from_props(valid_props(account: { name: "  " }))

	assert_equal [[:account, "must not be blank"]], errors_for(result)
end

# A nested value's own failure taints the prop that held it, so a rule reading
# it never judges a value already known to be invalid — while rules about
# sound props still speak.
test "a nested value's own failure silences only its readers" do
	result = Person.validate_from_props(id: "aaa", name: "", account: { name: "" })

	assert_equal(
		[[:account, "must not be blank"], [:name, "must be between 1 and 10 characters"]],
		errors_for(result)
	)
end

# The nested error carries the whole route, while `prop` stays the top-level
# property that held it, so an existing renderer keyed on `prop` keeps working.
test "a nested error keeps the full path under the prop that held it" do
	result = Person.validate_from_props(id: "aaa", name: "Ada", account: { name: "" })

	error = result.error!.errors.fetch(0)

	assert_equal %i[account name], error.path
	assert_equal :account, error.prop
end

test "this level's own error keeps its own path" do
	result = Person.validate_from_props(valid_props(name: ""))

	error = result.error!.errors.fetch(0)

	assert_equal [:name], error.path
	assert_equal :name, error.prop
end

test "a stipulation never reads a nested value that failed its own rules" do
	ran = false
	outer = Class.new(Literal::Data) do
		prop :account, Account
		stipulate(:account, "never reported") { |account| ran = true }
	end

	result = outer.validate_from_props(account: { name: "" })

	refute ran
	assert_equal [[:account, "must not be blank"]], errors_for(result)
end

# With the nested value sound, this level's stipulations do run and can read it.
test "a stipulation reads a nested value that passed its own rules" do
	seen = :never_ran
	outer = Class.new(Literal::Data) do
		prop :account, Account
		stipulate(:account, "must not be Initech") { |account| seen = account; account.name != "Initech" }
	end

	result = outer.validate_from_props(account: { name: "Initech" })

	assert Account === seen
	assert_equal "Initech", seen.name
	assert_equal [[:account, "must not be Initech"]], errors_for(result)
end

# A nested rule failure taints the prop that held it, so this level's rules
# that read it never run against a value already known invalid.
test "a nested rule failure silences this level's readers of it" do
	inner = Class.new(Literal::Data) do
		prop :name, String
		prop :code, String

		stipulate(:code, "bad code") { |code| code != "bad" }
	end

	outer = Class.new(Literal::Data) do
		prop :inner, inner

		stipulate("never reported") { |inner| inner.name.empty? }
	end

	result = outer.validate_from_props(inner: { name: "ada", code: "bad" })

	assert_equal(
		[[:inner, "bad code"]],
		result.error!.errors.map { |error| [error.prop, error.message] }
	)
end

test "a nested type failure does hold the stipulations back, leaving nothing to read" do
	ran = false
	outer = Class.new(Literal::Data) do
		prop :account, Account
		stipulate(:account, "never reported") { |account| ran = true }
	end

	result = outer.validate_from_props(account: { name: 42 })

	assert_equal [[:account, "must be a string"]], result.error!.errors.map { |error| [error.prop, error.message] }
	refute ran
end

test "a nested rule failure skips the rules that read it, not the rest" do
	ran = :never
	klass = Class.new(Literal::Data) do
		prop :account, Account
		prop :name, String

		stipulate("never reported") { |account| ran = account; false }
		stipulate(:name, "too short") { |name| name.size > 3 }
	end

	result = klass.validate_from_props(account: { name: "" }, name: "Jo")

	assert_equal :never, ran
	assert_equal [[:account, "must not be blank"], [:name, "too short"]], errors_for(result)
end

test "surfaces a nested type error under the prop that held it" do
	result = Person.validate_from_props(valid_props(account: { name: 42 }))

	assert_equal [[:account, "must be a string"]], errors_for(result)
end

test "carries the full path so a nested field can be placed exactly" do
	result = Person.validate_from_props(valid_props(account: { name: 42 }))

	assert_equal [%i[account name]], result.error!.errors.map(&:path)
end

test "a top-level error's path is the prop itself, a whole-value error none" do
	typed = Person.validate_from_props(valid_props(id: 1)).error!.errors.fetch(0)
	assert_equal [:id], typed.path

	based = Person.validate_from_props(valid_props(name: "Joe", account: { name: "ACME" })).error!.errors.fetch(0)
	assert based.path.empty?
end

test "accepts string keys inside a nested Hash" do
	assert Person.validate_from_props(valid_props(account: { "name" => "Initech" })).success?
end

test "accepts string keys at the top level" do
	props = { "id" => "per_1", "name" => "Ada", "account" => { "name" => "Initech" } }

	assert Person.validate_from_props(props).success?
end

# A HashWithIndifferentAccess's `transform_keys` answers another
# HashWithIndifferentAccess, which re-stringifies the interned Symbols — so
# interning has to build a plain Hash, or every field reads as unknown.
test "accepts a HashWithIndifferentAccess at the top level" do
	props = ActiveSupport::HashWithIndifferentAccess.new(
		id: "per_1", name: "Ada", account: { name: "Initech" },
	)

	assert Person.validate_from_props(props).success?
end

test "accepts a HashWithIndifferentAccess inside a nested prop" do
	props = valid_props(account: ActiveSupport::HashWithIndifferentAccess.new(name: "Initech"))

	assert Person.validate_from_props(props).success?
end

test "reports an unknown key inside a nested Hash under the prop that held it" do
	result = Person.validate_from_props(valid_props(account: { name: "Initech", junk: 1 }))

	assert_equal [[:account, "is not a known field"]], errors_for(result)
	assert_equal %i[account junk], result.error!.errors.fetch(0).path
end

# The un-validated branch reports by name too, rather than letting `new` raise
# about only the first of them.
test "reports an unknown key inside a nested Data that has no rules" do
	result = Person.validate_from_props(valid_props(address: { city: "London", junk: 1 }))

	assert_equal [[:address, "is not a known field"]], errors_for(result)
	assert_equal %i[address junk], result.error!.errors.fetch(0).path
end

test "builds a nested Data that has no rules of its own" do
	person = Person.validate_from_props(valid_props(address: { city: "London" })).value!

	assert_equal "London", person.address.city
end

# The shape's class name is not part of the message — it may be internal — but
# the field that failed is.
test "names the bad field of a nested Data with no rules of its own" do
	result = Person.validate_from_props(valid_props(address: { city: 42 }))

	assert_equal [[:address, "must be a string"]], errors_for(result)
	assert_equal %i[address city], result.error!.errors.fetch(0).path
end

test "takes an already-built nested instance as readily as a Hash" do
	result = Person.validate(**valid_props(account: Account.new(name: "Initech")))

	assert result.success?
end

# Every construction path enforces the rules, so an instance that exists already
# satisfies them. Nested validation trusts it rather than paying to re-check.
test "a nested instance is trusted, because it cannot have been built invalid" do
	assert_raises(Literal::ValidationError) { Account.new(name: "   ") }
	assert Person.validate(**valid_props(account: Account.new(name: "Initech"))).success?
end

test "a nested prop's coercion runs before nested validation" do
	inner = Class.new(Literal::Data) do
		prop :name, String
		stipulate(:name, "must not be blank") { |name| !name.empty? }
	end
	outer = Class.new(Literal::Data) do
		prop(:inner, inner) { |value| (Hash === value) ? inner.new(name: value[:wire_name].to_s) : value }
	end

	assert_equal "Ada", outer.validate_from_props(inner: { wire_name: "Ada" }).value!.inner.name
	assert_equal(
		[[:inner, "must not be blank"]],
		outer.validate_from_props(inner: { wire_name: "" }).error!.errors.map { |error| [error.prop, error.message] }
	)
end

# The common wire coercion normalizes keys and leaves the nested shape to build
# itself, so what the coercion returns has to reach nested validation as the
# Hash it is.
test "a nested prop's coercion may hand nested validation a Hash" do
	inner = Class.new(Literal::Data) do
		prop :name, String
		stipulate(:name, "must not be blank") { |name| !name.empty? }
	end
	outer = Class.new(Literal::Data) do
		prop(:inner, inner) { |value| (Hash === value) ? value.transform_keys(&:to_sym) : value }
	end

	assert_equal "Initech", outer.validate_from_props(inner: { "name" => "Initech" }).value!.inner.name
	assert_equal [[:inner, "must not be blank"]], errors_for(outer.validate_from_props(inner: { "name" => "" }))
end

test "takes a nested draft as a value and validates it by its shape" do
	account = Literal::Draft(Account).new
	account.name = ""

	result = Person.validate(**valid_props(account:))

	assert_equal [[:account, "must not be blank"]], errors_for(result)

	account.name = "Initech"
	assert Person.validate(**valid_props(account:)).success?
end

test "a draft of the wrong shape is a plain type failure" do
	result = Person.validate_from_props(valid_props(account: Literal::Draft(Address).new))

	assert_equal [[:account, "is not allowed"]], errors_for(result)
end

test "leaves an open Hash prop as the Hash it is" do
	klass = Class.new(Literal::Data) do
		prop :metadata, _Hash(String, String)
	end

	assert_equal({ "a" => "b" }, klass.validate(metadata: { "a" => "b" }).value!.metadata)
end

# --- result plumbing ---

test "handle dispatches the success branch with the instance" do
	seen = nil
	Person.validate_from_props(valid_props).handle do |on|
		on.success { |person| seen = person.name }
		on.failure { raise "expected success" }
	end

	assert_equal "Ada", seen
end

test "handle dispatches the failure branch with the validation errors" do
	seen = nil
	Person.validate_from_props(valid_props(id: 1)).handle do |on|
		on.success { raise "expected failure" }
		on.failure { |errors| seen = errors.errors.size }
	end

	assert_equal 1, seen
end

# --- declaration guards ---

# The predicate is the rule, so there is nothing for `stipulate` to declare
# without one.
test "stipulate raises without a block" do
	assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			stipulate(:name, "…")
		end
	end
end

# A single anonymous parameter — `it`, or a lone `_1` — reads the property the
# failure is filed against, so the common one-property rule needs no name.
test "it reads the pinned property" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer

		stipulate(:min, "must not be negative") { !it.negative? } # rubocop:disable Lint/ItWithoutArgumentsInBlock
	end

	assert_equal 1, klass.new(min: 1).min

	error = assert_raises(Literal::ValidationError) { klass.new(min: -1) }
	assert error.message.include?("must not be negative")
end

test "a lone _1 reads the pinned property" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer

		stipulate(:min, "must not be negative") { !_1.negative? } # rubocop:disable Style/NumberedParameters
	end

	assert klass.new(min: 1).valid?
	assert_raises(Literal::ValidationError) { klass.new(min: -1) }
end

# `%{}` slots name reads, and the pinned property is the read.
test "it fills the pinned property's message slot" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer

		stipulate(:min, "cannot be %{min}") { !it.negative? } # rubocop:disable Lint/ItWithoutArgumentsInBlock
	end

	error = assert_raises(Literal::ValidationError) { klass.new(min: -3) }
	assert error.message.include?("cannot be -3")
end

# A whole-value stipulation pins no property, so an anonymous parameter has
# nothing to read.
test "it in a whole-value stipulation is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			stipulate("…") { it.empty? } # rubocop:disable Lint/ItWithoutArgumentsInBlock
		end
	end

	assert(/whole-value/.match?(error.message))
end

# Beyond the first, a numbered parameter names nothing to read.
test "multiple numbered parameters are refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			prop :max, Integer
			stipulate(:max, "…") { _1 < _2 } # rubocop:disable Style/NumberedParameters
		end
	end

	assert(/numbered/.match?(error.message))
end

# A keyword parameter reads the property it names, exactly as a positional one
# does — the values just arrive by name instead of by position.
test "keyword parameters read the properties they name" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		stipulate(:max, "must be greater than %{min}") { |min:, max:| max > min }
	end

	assert klass.validate(min: 1, max: 5).success?
	assert_equal [[:max, "must be greater than 5"]], errors_for(klass.validate(min: 5, max: 1))
end

test "positional and keyword parameters mix" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		stipulate(:max, "must be greater than %{min}") { |max, min:| max > min }
	end

	assert klass.validate(min: 1, max: 5).success?
	assert_equal [[:max, "must be greater than 5"]], errors_for(klass.validate(min: 5, max: 1))
end

test "a keyword parameter with a default still reads its property" do
	klass = Class.new(Literal::Data) do
		prop :n, Integer
		stipulate(:n, "must be positive") { |n: 0| n.positive? }
	end

	assert klass.validate(n: 1).success?
	assert_equal [[:n, "must be positive"]], errors_for(klass.validate(n: -1))
end

# A property named after a reserved word cannot be a positional parameter at
# all — `{ |end| ... }` does not parse. As a keyword it declares and binds,
# and the body reads the value through the binding.
test "a keyword parameter spells a reserved-word property" do
	klass = Class.new(Literal::Data) do
		prop :begin, Integer
		prop :end, Integer

		stipulate(:end, "must be after %{begin}") { |begin:, end:|
			binding.local_variable_get(:end) > binding.local_variable_get(:begin)
		}
	end

	assert klass.validate(begin: 1, end: 5).success?
	assert_equal [[:end, "must be after 5"]], errors_for(klass.validate(begin: 5, end: 1))
end

test "a keyword parameter naming no property raises at declaration time" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			stipulate(:name, "…") { |nope:| false }
		end
	end

	assert error.message.include?(":nope")
end

# A `**` catch-all names nothing to read, like `*` and `&` before it.
test "a keyword rest parameter is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			stipulate(:name, "…") { |**props| false }
		end
	end

	assert(/cannot take :keyrest/.match?(error.message))
end

# The writer of a property a stipulation reads re-runs it, however the read is
# spelled.
test "a writer enforces a stipulation that reads by keyword" do
	klass = Class.new(Literal::Object) do
		prop :min, Integer, writer: :public
		prop :max, Integer, writer: :public
		stipulate(:max, "must be greater than %{min}") { |min:, max:| max > min }
	end

	instance = klass.new(min: 1, max: 5)
	assert_raises(Literal::ValidationError) { instance.min = 10 }
	assert_equal 1, instance.instance_variable_get(:@min)
end

test "a keyword read of an ungiven undefinable property does not apply" do
	klass = Class.new(Literal::Data) do
		prop? :nickname, String
		stipulate(:nickname, "must be short") { |nickname:| nickname.size <= 5 }
	end

	assert klass.validate.success?
	assert_equal [[:nickname, "must be short"]], errors_for(klass.validate(nickname: "Bartholomew"))
end

# A predicate with no parameters reads nothing, so it is a constant, not a
# rule — and on Ruby 3.3 a bare `it` also reports no parameters, so accepting
# zero would let it through to raise a NameError out of construction there.
test "a predicate with no parameters is refused at declaration" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			stipulate(:name, "is never allowed") { false }
		end
	end

	assert(/at least one/.match?(error.message))
end

# The property a failure is reported against is checked where the stipulation is
# written, not on the first value that reaches it — otherwise a typo sits latent
# and then raises out of every construction of the shape.
test "reporting against a prop the shape does not have raises at declaration time" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			stipulate(:nope, "…") { false }
		end
	end

	assert(/nope/.match?(error.message))
end

# --- inheritance ---

# A subclass inherits its parent's props, so it inherits what guards them too.
class Base < Literal::Data
	prop :name, String

	stipulate(:name, "base says blank") { |name| !name.empty? }
end

class Sub < Base
	prop :extra, _Nilable(String)

	stipulate(:name, "sub says short") { |name| name.size >= 3 }
end

class SubSub < Sub
	stipulate("subsub says so") { |name| false }
end

test "a subclass inherits its parent's stipulations" do
	assert_equal [[:name, "base says blank"]], Base.validate(name: "").error!.errors.map { |error| [error.prop, error.message] }
	assert_includes Sub.validate(name: "").error!.errors.map(&:message), "base says blank"
end

# A subclass's rules sit after its parent's, so a rule reading a property the
# parent's rule failed is skipped — it may assume the parent's invariant holds.
test "inherited stipulations run before the subclass's own" do
	# The parent's rule taints name, so the subclass's never runs.
	assert_equal ["base says blank"], Sub.validate(name: "").error!.errors.map(&:message)
	# With the parent's satisfied, name is untainted and the subclass's runs.
	assert_equal ["sub says short"], Sub.validate(name: "Jo").error!.errors.map(&:message)
end

test "a subclass's own stipulations do not leak back to its parent" do
	assert_equal ["base says blank"], Base.validate(name: "").error!.errors.map(&:message)
	assert_equal 1, Base.stipulations.size
	assert_equal 2, Sub.stipulations.size
end

test "inheritance carries down more than one level" do
	# Each level's rule passes in turn, so the third level's is reached.
	assert_equal ["subsub says so"], SubSub.validate(name: "Ada").error!.errors.map(&:message)
	# And a failure at the first level stops the two below it.
	assert_equal ["base says blank"], SubSub.validate(name: "").error!.errors.map(&:message)
end

test "a subclass validates the props it added as well as the ones it inherited" do
	assert_equal [[:extra, "must be a string"]], Sub.validate_from_props(name: "Ada", extra: 42).error!.errors.map { |error| [error.prop, error.message] }
end

# A frozen class can still be asked for its stipulations, it just cannot cache them —
# lazy resolution must not turn the first validated write on a frozen subclass
# into a FrozenError.
test "a frozen subclass still enforces on write and answers valid?" do
	parent = Class.new(Literal::Struct) do
		prop :min, Integer
		prop :max, Integer
		stipulate(:max, "must be greater than min") { |min, max| max > min }
	end
	child = Class.new(parent)
	object = child.new(min: 1, max: 5)
	child.freeze

	assert object.valid?
	assert_raises(Literal::ValidationError) { object.max = 0 }
	assert_equal 5, object.max

	object.max = 9

	assert_equal 9, object.max
end

# Declaring on a frozen shape — an enum after its class body has closed — can
# never install, so it is refused by name rather than left to the bare
# FrozenError the rule install would raise.
test "stipulate on a frozen shape raises at the declaration" do
	klass = Class.new(Literal::Data) do
		prop :count, Integer
	end
	klass.freeze

	error = assert_raises(Literal::ArgumentError) do
		klass.stipulate(:count, "must be positive") { |count| count > 0 }
	end

	assert(/frozen/.match?(error.message))
end

# As `prop` does: a rule added after a subclass exists would leave the subclass
# less constrained than its parent while still passing as it.
test "stipulate on a shape a subclass has inherited raises at the declaration" do
	klass = Class.new(Literal::Data) do
		prop :count, Integer
	end
	Class.new(klass)

	error = assert_raises(Literal::ArgumentError) do
		klass.stipulate(:count, "must be positive") { |count| count > 0 }
	end

	assert error.message.include?("already inherited")
end

# Stipulations resolve through the superclass the way literal_properties does, not
# through an inherited hook — a hook is silently lost when a class overrides
# `inherited` without calling super, and the subclass would construct objects
# its parent's invariant forbids.
test "stipulations survive an inherited override that forgets super" do
	parent = Class.new(Literal::Struct) do
		prop :min, Integer
		stipulate(:min, "must not be negative") { |min| !min.negative? }

		def self.inherited(subclass); end
	end
	child = Class.new(parent)

	assert_raises(Literal::ValidationError) { child.new(min: -1) }
end

# --- validate agrees with new ---

# The property that makes this predictable: for any input `new` accepts,
# `validate` must accept it too, and build the same value. `validate` is
# deliberately laxer in what shapes of input it takes — a Hash or draft for a
# nested prop, String keys — but never stricter about the values themselves.
#
# So it has to run the same pipeline the generated initializer runs:
# default, coerce, seal, check. The seal is the one that bites: it fixes a
# value's final representation, and that representation is what the type
# describes, so checking before sealing rejects every value a sealed prop holds.

test "a sealed prop accepts what new accepts" do
	klass = Class.new(Literal::Data) do
		prop :name, _Frozen(String), &Literal.Seal { |value| value.frozen? ? value : value.dup.freeze }
	end

	assert klass.new(name: +"mutable").name.frozen?
	assert klass.validate(name: +"mutable").value!.name.frozen?
end

test "a prop with both a coercion and a seal runs the coercion first" do
	klass = Class.new(Literal::Data) do
		prop :n, _Frozen(String), &(Literal.Coercion(&:to_s) >> Literal.Seal { |value| value.frozen? ? value : value.dup.freeze })
	end

	assert_equal "5", klass.new(n: 5).n
	assert_equal "5", klass.validate(n: 5).value!.n
	assert klass.validate(n: 5).value!.n.frozen?
end

# The initializer coerces a default, so a shape whose default is written in its
# input's terms resolves the same way either way.
test "a default goes through the prop's coercion" do
	klass = Class.new(Literal::Data) do
		prop(:n, Integer, default: -> { "7" }) { |value| Integer(value) }
	end

	assert_equal 7, klass.new.n
	assert_equal 7, klass.validate.value!.n
end

test "a default goes through the prop's seal" do
	klass = Class.new(Literal::Data) do
		prop :name, _Frozen(String), default: -> { +"mutable" }, &Literal.Seal { |value| value.frozen? ? value : value.dup.freeze }
	end

	assert klass.new.name.frozen?
	assert klass.validate.value!.name.frozen?
end

# A draft's slots carry values the prop's seal has not judged yet. When the
# seal raises after the input was already rejected, the raise is swallowed —
# and the slot must then read as unset, not as the value the seal refused,
# or a rule would judge and splice a value the type pass never accepted.
test "a slot whose seal raised reads as unset, not as the input's value" do
	klass = Class.new(Literal::Data) do
		prop :a, Integer
		prop :b, String, &Literal.Seal { |value| raise "boom" if value == "boom"; value }

		stipulate(:b, "must not be %{b}") { |b| b != "boom" }
	end

	draft = Literal::Draft(klass).new(b: "boom")
	assert_equal [[:a, "is missing"]], errors_for(draft.validate)
end

# A seal fixes a representation once, not once per hop. The soft path seals as
# it checks, so the build it finishes with must not seal again.
test "every path coerces once and seals once" do
	coercions = 0
	seals = 0
	klass = Class.new(Literal::Data) do
		prop :name, String, &(Literal.Coercion { |value| coercions += 1; value.to_s } >> Literal.Seal { |value| seals += 1; value })
	end

	counts = {}
	{
		new: -> { klass.new(name: "a") },
		validate_args: -> { klass.validate(name: "a").value! },
		validate_props: -> { klass.validate_from_props(name: "a").value! },
		validate_draft: -> { Literal::Draft(klass).new(name: "a").validate.value! },
		validate_instance: -> { klass.new(name: "a").validate.value! },
		finalize: -> { Literal::Draft(klass).new(name: "a").finalize },
	}.each do |label, build|
		coercions = 0
		seals = 0
		build.call
		counts[label] = [coercions, seals]
	end

	assert_equal(
		{ new: [1, 1], validate_args: [1, 1], validate_props: [1, 1], validate_draft: [1, 1], validate_instance: [1, 1], finalize: [1, 1] },
		counts,
	)
end

# A draft slot is deliberately laxer than the prop it stands in for, so a value
# already assigned to a draft still has to be sealed and checked here.
test "a value already on a draft is sealed and checked against the prop's real type" do
	klass = Class.new(Literal::Data) do
		prop :name, _Frozen(String), &Literal.Seal { |value| value.frozen? ? value : value.dup.freeze }
	end
	draft = Literal::Draft(klass).new
	draft.name = +"mutable"

	refute draft.name.frozen?
	assert draft.validate.value!.name.frozen?
end

# --- writers enforce too ---

# A writer enforces the stipulations whose outcome depends on its property, so an
# object is valid always, not only at construction.
test "a writer enforces a stipulation that reads its property, wherever the error is filed" do
	klass = Class.new(Literal::Struct) do
		prop :min, Integer
		prop :max, Integer
		stipulate(:max, "must be greater than min") { |min, max| max > min }
	end
	span = klass.new(min: 1, max: 5)

	# Filed against :max, but writing :min changes the outcome, so :min's writer
	# enforces it too.
	assert_raises(Literal::ValidationError) { span.min = 10 }
	assert_equal 1, span.min

	assert_raises(Literal::ValidationError) { span.max = 0 }
	assert_equal 5, span.max

	span.max = 9

	assert_equal 9, span.max
end

# Where the error goes has no bearing on whether the outcome can change, so a
# writer for a property that is only ever reported against — never read — has
# nothing to enforce and no check emitted.
test "a property no stipulation depends on gets no check in its writer" do
	klass = Class.new(Literal::Struct) do
		prop :n, Integer
		prop :note, String
		stipulate(:n, "must be positive") { |n| n > 0 }
	end
	object = klass.new(n: 1, note: "x")

	refute_includes klass.literal_properties[:note].generate_writer_method(+""), "__literal_check_rules__"

	object.note = "y"

	assert_equal "y", object.note
	assert_raises(Literal::ValidationError) { object.n = -1 }
end

# Two interdependent properties cannot be moved one at a time — the intermediate
# state is exactly what the stipulation forbids. That transition goes through a
# draft or `from_props`, which judge the whole value at once.
test "a transition that needs two properties at once goes through from_props" do
	klass = Class.new(Literal::Struct) do
		prop :min, Integer
		prop :max, Integer
		stipulate(:max, "must be greater than min") { |min, max| max > min }
	end
	span = klass.new(min: 1, max: 5)

	assert_raises(Literal::ValidationError) { span.min = 10 }

	moved = klass.from_props(span.to_h.merge(min: 10, max: 20))

	assert_equal [10, 20], [moved.min, moved.max]
end

# The rules judge the prospective value before it is stored, so a predicate
# that raises out of its own bug — not just one that fails — leaves the object
# untouched, holding a value its rules can still be evaluated against.
test "a raising predicate leaves the written property untouched" do
	klass = Class.new(Literal::Struct) do
		prop :min, _Nilable(Integer)
		prop :max, Integer
		stipulate(:max, "must be greater than min") { |min, max| max > min }
	end
	span = klass.new(min: 1, max: 5)

	assert_raises(ArgumentError) { span.min = nil }

	assert_equal 1, span.min
	assert span.valid?
end

# An unvalidated writer ends with the assignment and answers the value, so a
# validated one must too — `send(:"#{name}=", value)` chains read the result.
test "a validated writer returns the written value" do
	klass = Class.new(Literal::Struct) do
		prop :n, Integer
		stipulate(:n, "must be positive") { |n| n > 0 }
	end
	object = klass.new(n: 1)

	assert_equal 9, object.__send__(:n=, 9)
end

# --- what a stipulation is handed ---

# An undefinable property that was not given holds Literal::Undefined, which is
# not a value to judge — so a stipulation reading one does not apply, rather than
# meeting the sentinel where it expects an Integer.
test "a stipulation reading an undefinable prop does not apply when it was not given" do
	klass = Class.new(Literal::Data) do
		prop :a, Integer
		prop? :b, Integer
		stipulate(:b, "must be positive") { |b| b > 0 }
	end

	assert_equal Literal::Undefined, klass.new(a: 1).b
	assert klass.validate(a: 1).success?
	assert klass.validate_from_props({ a: 1 }).success?
	assert_equal [[:b, "must be positive"]], errors_for(klass.validate_from_props({ a: 1, b: -1 }))
end

# nil is a value, so a nilable property that was given nothing is still judged.
test "a stipulation reading a nilable prop applies to the nil" do
	klass = Class.new(Literal::Data) do
		prop :n, _Nilable(Integer)
		stipulate(:n, "must be given") { |n| !n.nil? }
	end

	assert_equal [[:n, "must be given"]], errors_for(klass.validate_from_props({}))
end

# The values are the caller's own objects, so a stipulation can mutate one. It is
# handed them to read; mutating one reaches the built value.
test "a stipulation is handed the caller's own values" do
	seen = nil
	klass = Class.new(Literal::Data) do
		prop :tags, _Array(String)
		stipulate(:tags, "must not be empty") { |tags| seen = tags; !tags.empty? }
	end
	tags = ["a"]

	klass.new(tags:)

	assert seen.equal?(tags)
end

# --- a nested shape is any shape that builds from props ---

test "a nested Literal::Struct is validated by its own stipulations" do
	inner = Class.new(Literal::Struct) do
		prop :n, Integer
		stipulate(:n, "must be positive") { |n| n > 0 }
	end
	outer = Class.new(Literal::Data) { prop :inner, inner }

	assert outer.validate_from_props({ inner: { n: 1 } }).success?

	result = outer.validate_from_props({ inner: { n: -1 } })

	assert_equal [[:inner, "must be positive"]], errors_for(result)
	assert_equal %i[inner n], result.error!.errors.fetch(0).path
end

# Naming itself is the only way a shape can be recursive, so a deferred type has
# to nest like a direct reference — otherwise no recursive shape can be validated
# from props at all, which is the input this exists for.
test "a nested shape reached through _Deferred is validated by its own stipulations" do
	assert Node.validate_from_props({ n: 1, child: { n: 2, child: nil } }).success?

	result = Node.validate_from_props({ n: 1, child: { n: -2, child: nil } })

	assert_equal [[:child, "must be positive"]], errors_for(result)
	assert_equal %i[child n], result.error!.errors.fetch(0).path
end

test "a deferred shape given a scalar reads as an object, not as not allowed" do
	assert_equal [[:child, "must be an object"]], errors_for(Node.validate_from_props({ n: 1, child: 42 }))
end

# The wrappers validate sees through are exactly the ones a draft slot relaxes —
# _Frozen fixes representation and prop?'s union marks omittability, neither
# changes what the value must be — so `draft.validate` agrees with
# `draft.finalize` and a nested Hash reaches the shape either way.
test "a nested shape reached through _Frozen is validated by its own stipulations" do
	outer = Class.new(Literal::Data) { prop :account, _Frozen(Account) }

	result = outer.validate_from_props({ account: { name: " " } })

	assert_equal [[:account, "must not be blank"]], errors_for(result)
	assert_equal %i[account name], result.error!.errors.fetch(0).path
end

test "a nested shape in a prop? slot is validated by its own stipulations" do
	outer = Class.new(Literal::Data) do
		prop :id, String
		prop? :account, Account
	end

	assert_equal "x", outer.validate_from_props({ id: "1", account: { name: "x" } }).value!.account.name
	assert_equal(
		[[:account, "must not be blank"]],
		errors_for(outer.validate_from_props({ id: "1", account: { name: " " } }))
	)
end

# Which of two union members a Hash meant is not knowable, so it is not judged
# against an arbitrarily chosen one.
test "a Hash for a union of two shapes reads as a plain type failure" do
	other = Class.new(Literal::Data) { prop :name, String }
	outer = Class.new(Literal::Data) { prop :value, _Union(Account, other) }

	result = outer.validate_from_props({ value: { name: "x" } })

	assert_equal [[:value, "is not allowed"]], errors_for(result)
end

# A subclass draft carries props and rules its declared slot's shape knows
# nothing about; validating it as the declared shape would drop them silently.
test "a nested subclass draft validates as its own class" do
	employee = Class.new(Account) do
		prop :dept, String
		stipulate(:dept, "must not be blank") { |dept| !dept.strip.empty? }
	end
	outer = Class.new(Literal::Data) { prop :account, Account }

	draft = Literal::Draft(outer).new
	draft[:account] = Literal::Draft(employee).new(name: "Ada", tier: nil, dept: " ")

	assert_equal [[:account, "must not be blank"]], errors_for(draft.validate)

	draft[:account] = Literal::Draft(employee).new(name: "Ada", tier: nil, dept: "Ops")
	built = draft.validate.value!.account

	assert employee === built
	assert_equal "Ops", built.dept
end

# A Hash the prop's type already admits is a value, not a nested shape — `new`
# would store it as it is, and validate must agree.
test "a Hash a union member admits stays a Hash" do
	klass = Class.new(Literal::Data) { prop :value, _Union(Account, Hash) }

	assert_equal({ anything: 1 }, klass.new(value: { anything: 1 }).value)
	assert_equal({ anything: 1 }, klass.validate_from_props({ value: { anything: 1 } }).value!.value)
	assert_equal({ name: "x" }, klass.validate_from_props({ value: { name: "x" } }).value!.value)
end

# One shape reachable twice — directly and through _Deferred — is still one
# shape, not an ambiguity.
test "a shape reachable through two union members nests once" do
	klass = Class.new(Literal::Data) do
		extend Literal::Types
		prop :node, _Union(Node, _Deferred { Node })
	end

	assert_equal 1, klass.validate_from_props({ node: { n: 1, child: nil } }).value!.node.n
end

test "a draft in a _Frozen slot validates as it finalizes" do
	outer = Class.new(Literal::Data) { prop :account, _Frozen(Account) }
	draft = Literal::Draft(outer).new
	draft[:account] = Literal::Draft(Account).new(name: "Initech", tier: nil)

	assert draft.valid?
	assert_equal "Initech", draft.finalize.account.name
	assert_equal "Initech", draft.validate.value!.account.name
end

# Nesting is bounded because a SystemStackError is not a StandardError, so an
# unbounded walk would escape the boundary validate_from_props is supposed to be.
# Only a deferred type can cycle, so this is the case the cap exists for.
test "cyclic input reports rather than exhausting the stack" do
	props = { n: 1 }
	props[:child] = props

	result = Node.validate_from_props(props)
	error = result.error!.errors.fetch(-1)

	assert result.failure?
	assert_equal "is nested too deeply", error.message
	assert_equal 65, error.path.size
end

# --- declaration guards on the message ---

test "a message that is not a String raises at declaration time" do
	[:symbolic, -> (min) { "must exceed #{min}" }].each do |message|
		error = assert_raises(Literal::ArgumentError) do
			Class.new(Literal::Data) do
				prop :min, Integer
				stipulate(:min, message) { |min| min > 0 }
			end
		end

		assert(/message is a String/.match?(error.message))
	end
end

# A slot is filled with a value the predicate judged, so it can only name a
# property the stipulation reads — and a typo raises where it was written
# rather than on the first value that fails.
test "a message slot naming a property the stipulation does not read raises at declaration time" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			prop :max, Integer
			stipulate(:min, "must be under %{max}") { |min| min > 0 }
		end
	end

	assert(/does not read :max/.match?(error.message))
end

# --- validate_from_props takes props ---

# It is the entry point for input from outside, and a Hash is what that input
# is. A draft or an instance is asked directly instead.
test "validate_from_props takes only a Hash" do
	[nil, [], 42, Literal::Draft(Account).new, Account.new(name: "Initech")].each do |input|
		error = assert_raises(Literal::ArgumentError) { Account.validate_from_props(input) }

		assert(/takes a Hash of properties/.match?(error.message))
	end
end

# --- rules are the invariant: construction enforces them ---

# Every path that hands out an object enforces the rules, so an object that
# exists satisfies them. That is what lets nested validation trust an instance.
test "every construction path raises for a value that breaks a rule" do
	[
		-> { Account.new(name: " ") },
		-> { Account.from_props({ name: " " }) },
		-> { Account.from(Account.allocate.tap { |a| a.instance_variable_set(:@name, " ") }) },
		-> { Account.build { |draft| draft.name = " " } },
		-> { Literal::Draft(Account).new(name: " ").finalize },
		-> { Literal::SerializationContext.new.deserialize({ "name" => " " }, type: Account) },
	].each do |construct|
		assert_raises(Literal::ValidationError) { construct.call }
	end
end

# The unchecked finalizer is the validator's alone: public, it would be a
# construction path that skips the rules.
test "a draft cannot be finalized unchecked from outside" do
	draft = Literal::Draft(Account).new(name: " ")

	assert_raises(NoMethodError) { draft.__finalize_unchecked__ }
end

test "restoring a dumped object enforces its rules too" do
	version, attributes, was_frozen, frozen_values = Account.new(name: "Initech").as_pack
	pack = [version, attributes.merge(name: " "), was_frozen, frozen_values]

	assert_raises(Literal::ValidationError) { Account.allocate.marshal_load(pack) }
end

test "an enum member that breaks a rule raises at its definition" do
	assert_raises(Literal::ValidationError) do
		Class.new(Literal::Enum(Integer)) do
			prop :code, Integer
			stipulate(:code, "must be positive") { |code| code > 0 }

			def self.name = "Grade"
			const_set(:A, new(1, code: -1))
		end
	end
end

# Members are idiomatically defined above the rules in the class body. A
# member must satisfy its shape's rules like any other instance, so a rule
# declared below one enforces it retroactively — at the declaration, not left
# latent for nested validation to trust.
test "stipulate enforces existing enum members retroactively" do
	assert_raises(Literal::ValidationError) do
		Class.new(Literal::Enum(Integer)) do
			prop :code, Integer

			def self.name = "Grade"
			const_set(:A, new(1, code: -1))

			stipulate(:code, "must be positive") { |code| code > 0 }
		end
	end
end

# Members are judged before the rule installs, so a rescued failure leaves
# the shape without the rule rather than a live rule behind a member that
# breaks it — a stipulate that fails must not half-happen.
test "a stipulate refused by an enum member installs nothing" do
	klass = Class.new(Literal::Enum(Integer)) do
		prop :code, Integer

		def self.name = "Grade"
		const_set(:A, new(1, code: -1))

		begin
			stipulate(:code, "must be positive") { |code| code > 0 }
		rescue Literal::ValidationError
			# The refusal is the point; what matters is what it left behind.
		end
	end

	assert_equal [], klass.stipulations
end

test "stipulate accepts existing enum members that satisfy it" do
	klass = Class.new(Literal::Enum(Integer)) do
		prop :code, Integer

		def self.name = "Grade"
		const_set(:A, new(1, code: 1))

		stipulate(:code, "must be positive") { |code| code > 0 }
	end

	assert klass::A.valid?
end

# A member's customization block runs after the initializer validated, so the
# rules are judged again on the state it left — and before the member
# registers, so a failure leaves nothing behind.
test "a member block that breaks a rule raises and registers nothing" do
	error = assert_raises(Literal::ValidationError) do
		Class.new(Literal::Enum(Integer)) do
			prop :code, Integer

			def self.name = "Grade"

			stipulate(:code, "must be positive") { |code| code > 0 }

			new(1, code: 1) do
				@code = -1
			end
		end
	end

	assert error.message.include?("must be positive")
end

test "a member block that keeps the rules registers the member" do
	klass = Class.new(Literal::Enum(Integer)) do
		prop :code, Integer

		def self.name = "Grade"

		stipulate(:code, "must be positive") { |code| code > 0 }

		const_set(:A, new(1, code: 1) do
			@code = 2
		end)
	end

	assert_equal 2, klass::A.code
	assert klass::A.valid?
end

# Uniqueness is judged on the value the block left, not the one the
# initializer was given.
test "a member block that mutates the value cannot duplicate another member" do
	error = assert_raises(ArgumentError) do
		Class.new(Literal::Enum(Integer)) do
			prop :code, Integer

			def self.name = "Grade"
			const_set(:A, new(1, code: 1))

			new(2, code: 1) do
				@value = 1
			end
		end
	end

	assert error.message.include?("already used")
end

# The failure reports from the stipulate declaration, trimmed of literal's own
# frames like every other rules path.
test "a retroactive member failure reports from the caller's code" do
	error = assert_raises(Literal::ValidationError) do
		Class.new(Literal::Enum(Integer)) do
			prop :code, Integer

			def self.name = "Grade"
			const_set(:A, new(1, code: -1))

			stipulate(:code, "must be positive") { |code| code > 0 }
		end
	end

	refute error.backtrace.first.include?("lib/literal")
end

test "the error carries every failure collected, not just the first" do
	klass = Class.new(Literal::Data) do
		prop :a, Integer
		prop :b, Integer

		stipulate(:a, "first") { |a| false }
		stipulate(:b, "second") { |b| false }
	end

	error = assert_raises(Literal::ValidationError) { klass.new(a: 1, b: 2) }

	assert_equal ["first", "second"], error.errors.errors.map(&:message)
end

# The rules step is emitted into the generated initializer, so without trimming
# the backtrace would start inside the eval'd code rather than at the caller.
test "the error reports from the caller, not from the generated initializer" do
	error = assert_raises(Literal::ValidationError) { Account.new(name: " ") }

	assert_includes error.backtrace.first, "validations.test.rb"
end

# It never carries the offending object: rules are the invariant, so a value
# that breaks them is not handed out by any route, the error included.
test "the error does not carry the invalid object" do
	error = assert_raises(Literal::ValidationError) { Account.new(name: " ") }

	assert_equal Account, error.shape
	refute error.respond_to?(:subject)
end

# The initializer is re-emitted when the first rule is declared, so declaration
# order within the class body does not matter.
test "a rule declared after the props is still enforced" do
	klass = Class.new(Literal::Data) do
		prop :n, Integer
		stipulate(:n, "must be positive") { |n| n > 0 }
	end

	assert_raises(Literal::ValidationError) { klass.new(n: -1) }
end

# A subclass that adds no prop has no generated extension of its own until it
# declares a rule, and would otherwise inherit an initializer that never checks.
test "a subclass that adds only a rule enforces it, and its parent does not" do
	parent = Class.new(Literal::Data) { prop :n, Integer }
	child = Class.new(parent) do
		stipulate(:n, "must be positive") { |n| n > 0 }
	end

	assert_raises(Literal::ValidationError) { child.new(n: -1) }
	assert_equal(-1, parent.new(n: -1).n)
end

test "a shape with no rules emits no check" do
	klass = Class.new(Literal::Data) { prop :n, Integer }

	refute_includes klass.literal_properties.generate_initializer(+""), "__literal_check_rules__"
end

# A draft is the shape's rules held in abeyance — that is what it is for — so it
# must never enforce the drafted type's rules at its own construction.
test "a draft of a shape with rules is not validated when it is built" do
	draft = Literal::Draft(Account).new(name: " ")

	assert_equal " ", draft.name
	refute draft.valid?
	assert_equal [[:name, "must not be blank"]], errors_for(draft.validate)
end

# validate must not raise, whatever a coercion does — and a nested value that
# broke its own rules has field errors worth keeping.
test "a coercion that builds an invalid nested value reports under its prop" do
	klass = Class.new(Literal::Data) do
		prop(:account, Account) { |value| (Hash === value) ? Account.new(name: value[:wire_name]) : value }
	end

	result = klass.validate_from_props(account: { wire_name: " " })

	assert_equal [[:account, "must not be blank"]], errors_for(result)
	assert_equal %i[account name], result.error!.errors.fetch(0).path
end

# --- projections ---

# A projection keeps the stipulations that still mean something: every property
# one touches has to survive the slice, since a stipulation that reads a dropped
# property has nothing to read.
test "slice keeps the stipulations whose properties all survive" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		stipulate(:min, "must not be negative") { |min| !min.negative? }
		stipulate(:max, "must be greater than min") { |min, max| max > min }
	end

	sliced = klass.slice(:min)

	assert_equal ["must not be negative"], sliced.stipulations.map(&:message)
end

# The projection is a shape in its own right, so what it kept is its invariant
# too — not a record of what the origin used to check.
test "a projection enforces the stipulations it kept" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		stipulate(:min, "must not be negative") { |min| !min.negative? }
		stipulate(:max, "must be greater than min") { |min, max| max > min }
	end

	sliced = klass.slice(:min)

	assert_raises(Literal::ValidationError) { sliced.new(min: -1) }
	assert_equal 1, sliced.new(min: 1).min
	assert_equal [[:min, "must not be negative"]], errors_for(sliced.validate(min: -1))
end

# A stipulation that loses a property it touches goes with it.
test "slice drops the stipulations whose properties went" do
	klass = Class.new(Literal::Data) do
		prop :name, String
		prop :code, String

		stipulate(:code, "must not be blank") { |code| !code.empty? }
		stipulate(:name, "must be filled") { |name| !name.empty? }
	end

	sliced = klass.slice(:name)

	assert_equal ["must be filled"], sliced.stipulations.map(&:message)
	assert_equal [[:name, "must be filled"]], errors_for(sliced.validate(name: ""))
end

# A projection's stipulations are set after its class body ran, so the writers it
# generated there knew nothing about them. Re-emitted, or the projection would
# enforce at construction and not on write — refusing an invalid object while
# letting one be mutated into the same state.
test "a projection's writers enforce the stipulations it kept" do
	klass = Class.new(Literal::Struct) do
		prop :min, Integer, writer: :public
		prop :max, Integer, writer: :public

		stipulate(:max, "must be greater than min") { |min, max| max > min }
	end

	sliced = klass.slice(:min, :max)
	projection = sliced.new(min: 1, max: 5)

	assert_raises(Literal::ValidationError) { projection.max = 0 }
	assert_equal 5, projection.max

	# The property read but not reported against is enforced the same way.
	assert_raises(Literal::ValidationError) { projection.min = 10 }
	assert_equal 1, projection.min

	projection.max = 9

	assert_equal 9, projection.max
end

# When the slice drops a property, the base walk passes the origin, so during
# the projection's class body its stipulations resolve to an ancestor's — and the
# per-property tables memoized then are stale once the kept rules are set.
test "a projection that drops a property still enforces in its writers" do
	klass = Class.new(Literal::Struct) do
		prop :min, Integer, writer: :public
		prop :max, Integer, writer: :public
		prop :note, String

		stipulate(:max, "must be greater than min") { |min, max| max > min }
	end

	sliced = klass.slice(:min, :max)
	projection = sliced.new(min: 1, max: 5)

	assert_raises(Literal::ValidationError) { projection.min = 10 }
	assert_equal 1, projection.min
end

# --- always on ---

test "every shape validates, with nothing to include" do
	assert Address.respond_to?(:stipulate)
	assert_equal "London", Address.validate(city: "London").value!.city
	assert_equal [[:city, "must be a string"]], errors_for(Address.validate_from_props(city: 42))
end
