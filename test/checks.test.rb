# frozen_string_literal: true

# Covers `check` and `checks`, and the two soft paths for them: `Draft#check`
# (with `Draft#sound?`) and `Draft.check`.
#
# Checks are the shape's invariant: every construction path enforces them,
# raising Literal::CheckError. The soft paths run them once the types hold,
# report every failure rather than the first, and answer a Literal::Result
# carrying the instance or Literal::Checks::Errors. Checks do not depend on
# one another, so every one whose reads survived the type pass answers.
#
# The two paths differ in the type pass. `Draft#check` judges values already on
# a draft, and a draft's own writers type check, so a wrong value raised there
# just as it would from `new`. `Draft.check` takes a Hash of props from outside,
# where nothing may raise, and reports type errors along with everything else.
class Account < Literal::Data
	prop :name, String
	prop :tier, _Nilable(String)

	check(:name, "must not be blank") { |name:| !name.strip.empty? }
end

# A nested Data with no checks of its own.
class Address < Literal::Data
	prop :city, String
end

# A shape that names itself, which only a deferred type can express.
class Node < Literal::Data
	prop :n, Integer
	prop :child, _Nilable(_Deferred { Node })

	check(:n, "must be positive") { |n:| n > 0 }
end

class Person < Literal::Data
	prop :id, String, description: "The person ID"
	prop :account, Account, description: "The person's account"
	prop :address, _Nilable(Address)
	prop :name, String
	prop :nickname, _Nilable(String)
	prop :role, String, default: -> { "member" }
	prop :tags, _Array(String), default: -> { [] }

	check(:name, "must be between 1 and 10 characters") { |name:| (1..10).cover?(name.size) }

	check("name can't be Joe when account is ACME") { |name:, account:| !(name == "Joe" && account.name == "ACME") }
end

def valid_props(**overrides)
	{ id: "per_1", name: "Ada", account: { name: "Initech" }, **overrides }
end

def errors_for(result)
	result.error!.errors.map { |error| [error.prop, error.message] }
end

# --- success ---

test "returns a Success carrying the built instance" do
	result = Literal::Draft(Person).check(valid_props)

	assert result.success?
	person = result.value!
	assert Person === person
	assert_equal "Ada", person.name
	assert_equal "Initech", person.account.name
end

test "checks a draft of the type it drafts" do
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Ada"
	draft.account = Account.new(name: "Initech", tier: nil)

	person = draft.check.value!

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

	person = draft.check.value!

	assert_equal "Ada", person.name
	assert_equal 1, runs
end

test "reports missing props on a draft" do
	draft = Literal::Draft(Person).new
	draft.name = "Ada"
	draft.account = Account.new(name: "Initech", tier: nil)

	assert_equal [[:id, "is missing"]], errors_for(draft.check)
end

# A draft class is cached against the schema it was made from, so a draft made
# before the shape gained a prop has no slot for it. That reads as unset — a
# report, not a NameError out of the soft path.
test "a draft made before the shape gained a prop reports it as missing" do
	klass = Class.new(Literal::Data) { prop :name, String }
	draft = Literal::Draft(klass).new(name: "Ada")
	klass.prop :age, Integer

	assert_equal [[:age, "is missing"]], errors_for(draft.check)
end

test "runs checks against a draft" do
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Joe"
	draft.account = Account.new(name: "ACME", tier: nil)

	assert_equal [[nil, "name can't be Joe when account is ACME"]], errors_for(draft.check)
end

test "a draft answers sound? as well as check" do
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Ada"
	draft.account = Account.new(name: "Initech", tier: nil)

	assert draft.sound?
	assert Person === draft.check.value!

	draft.name = ""

	refute draft.sound?
	assert_equal [[:name, "must be between 1 and 10 characters"]], errors_for(draft.check)
end

test "an untyped draft cannot be checked" do
	draft = Literal::Draft.new

	error = assert_raises(Literal::ArgumentError) { draft.check }
	assert_equal "Cannot check an untyped draft.", error.message
	assert_raises(Literal::ArgumentError) { draft.sound? }
	assert_raises(Literal::ArgumentError) { Literal::Draft.check({}) }
end

# Literal::Draft(T) already matches a draft of any subtype of T, and a subclass
# instance checks as its own class, so a subclass draft does too.
test "checks a draft of a subclass by the subclass" do
	child = Class.new(Account) do
		prop :code, String
		check(:code, "must not be blank") { |code:| !code.empty? }
	end

	draft = Literal::Draft(child).new(name: "Initech", code: "")

	assert_equal [[:code, "must not be blank"]], errors_for(draft.check)

	draft.code = "ACME"
	value = draft.check.value!

	assert_equal child, value.class
	assert_equal "ACME", value.code
end

# A draft checks through the type it drafts, so it can no longer be handed to
# the wrong shape at all — the mismatch the class-level form had to guard against
# is now unrepresentable.
test "a draft checks as the type it drafts, whatever else it is passed to" do
	draft = Literal::Draft(Account).new
	draft.name = ""

	assert_equal [[:name, "must not be blank"]], errors_for(draft.check)
	assert_equal Account, draft.check.success_type
end

test "never mutates a supplied draft" do
	draft = Literal::Draft(Person).new
	draft.name = "Ada"

	draft.check

	assert_equal "Ada", draft.name
	assert Literal::Undefined == draft.id
	assert Literal::Undefined == draft.tags
end

test "checking never freezes the caller's draft" do
	account = Literal::Draft(Account).new
	account.name = "Initech"
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Ada"
	draft.account = account

	assert draft.check.success?
	refute draft.frozen?
	refute account.frozen?

	draft.name = "Ida"
	assert draft.check.success?
end

test "a nested draft on a supplied draft is checked by its own shape" do
	account = Literal::Draft(Account).new
	account.name = ""
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Ada"
	draft.account = account

	result = draft.check

	assert_equal [[:account, "must not be blank"]], errors_for(result)
	assert_equal %i[account name], result.error!.errors.fetch(0).path
end

test "an incomplete nested draft reports its missing props rather than raising" do
	draft = Literal::Draft(Person).new
	draft.id = "per_1"
	draft.name = "Ada"
	draft.account = Literal::Draft(Account).new

	result = draft.check

	assert_equal [[:account, "is missing"]], errors_for(result)
	assert_equal %i[account name], result.error!.errors.fetch(0).path
end

# A shape with no checks of its own reports the same way as one with them:
# nested checking is not conditional on having checks.
test "an incomplete nested draft of a shape with no checks names the missing field" do
	outer = Class.new(Literal::Data) do
		prop :address, Address
	end
	draft = Literal::Draft(outer).new
	draft.address = Literal::Draft(Address).new

	result = draft.check

	assert_equal [[:address, "is missing"]], result.error!.errors.map { |error| [error.prop, error.message] }
	assert_equal %i[address city], result.error!.errors.fetch(0).path
end

test "applies prop defaults for props that were not given" do
	person = Literal::Draft(Person).check(valid_props).value!

	assert_equal "member", person.role
	assert_equal [], person.tags
end

test "leaves a nilable prop nil rather than treating it as missing" do
	assert Literal::Draft(Person).check(valid_props).value!.nickname.nil?
end

# `new` refuses an unknown keyword and `from_props` an unknown attribute, so a
# key the shape has no prop for is reported, not dropped. A mistyped field that
# vanished would read as one the caller never sent.
test "reports a key that is not a prop" do
	result = Literal::Draft(Person).check(valid_props(surprise: "unexpected"))

	assert_equal [[:surprise, "is not a known field"]], errors_for(result)
	assert_equal [:surprise], result.error!.errors.fetch(0).path
end

test "reports every unknown key, not just the first" do
	result = Literal::Draft(Person).check(valid_props(surprise: 1, shock: 2))

	assert_equal %i[surprise shock], result.error!.errors.map(&:prop)
end

test "an unknown key is reported alongside the props that are wrong" do
	result = Literal::Draft(Person).check(valid_props(id: 1, surprise: "unexpected"))

	assert_equal [[:surprise, "is not a known field"], [:id, "must be a string"]], errors_for(result)
end

# An unknown key may be a typo of a prop that then quietly defaulted, so a
# check reading a defaulted value has nothing trustworthy to judge. The given
# values are exactly what the caller sent, so checks over those still answer —
# the caller learns every fixable thing at once.
test "an unknown key holds back only the checks reading defaulted props" do
	ran = []
	klass = Class.new(Literal::Data) do
		prop :name, String
		prop :limit, Integer, default: 20
	end
	klass.check(:name, "must be filled") { |name:| ran << :name; !name.empty? }
	klass.check(:limit, "never reported") { |limit:| ran << :limit; true }

	result = Literal::Draft(klass).check(name: "", surprise: 1)

	assert_equal [[:surprise, "is not a known field"], [:name, "must be filled"]], errors_for(result)
	assert_equal [:name], ran
end

test "an unknown key holds back a check reading any defaulted prop" do
	ran = false
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer, default: 100
	end
	klass.check(:max, "never reported") { |max:, min:| ran = true }

	assert Literal::Draft(klass).check(min: 5, surprise: 1).failure?
	refute ran
end

test "a check over a defaulted prop answers again once the prop is given" do
	klass = Class.new(Literal::Data) do
		prop :limit, Integer, default: 20
	end
	klass.check(:limit, "must be at most 100") { |limit:| limit <= 100 }

	result = Literal::Draft(klass).check(limit: 500, surprise: 1)

	assert_equal [[:surprise, "is not a known field"], [:limit, "must be at most 100"]], errors_for(result)
end

# With every key understood, a default is a legitimate value like any other,
# and the checks judge it.
test "a check judges a defaulted value when every key is understood" do
	klass = Class.new(Literal::Data) do
		prop :limit, Integer, default: -1
	end
	klass.check(:limit, "must be positive", &:positive?)

	assert_equal [[:limit, "must be positive"]], errors_for(Literal::Draft(klass).check({}))
end

# Key confusion is judged per shape: a stray key inside a nested Hash taints
# the prop that held it, and the parent's other checks still answer.
test "an unknown key inside a nested shape stays there" do
	nested = Class.new(Literal::Data) { prop :city, String }
	klass = Class.new(Literal::Data) do
		prop :address, nested
		prop :name, String
	end
	klass.check(:name, "must be filled") { |name:| !name.empty? }

	result = Literal::Draft(klass).check(name: "", address: { city: "Berlin", junk: 1 })

	assert_includes errors_for(result), [:address, "is not a known field"]
	assert_includes errors_for(result), [:name, "must be filled"]
end

test "a string key that names no prop is reported as the symbol it interns to" do
	result = Literal::Draft(Person).check({ "surprise" => 1, **valid_props })

	assert_equal [[:surprise, "is not a known field"]], errors_for(result)
end

# `:name` and `"name"` collapse when String keys are interned, and which value
# survives depends on the order they were given in — a good value could vanish
# and pass, or vanish and be reported against. Neither is safe to pick, so the
# pair is reported and neither value is judged.
test "a key given in both spellings is reported as a duplicate" do
	result = Literal::Draft(Person).check({ "name" => "Ada", **valid_props(name: "Ada") })

	assert result.failure?
	assert_includes errors_for(result), [:name, "was given more than once"]
end

test "a duplicated key's values are not judged" do
	result = Literal::Draft(Person).check({ "name" => 42, **valid_props(name: "Ada") })

	assert_equal [[:name, "was given more than once"]], errors_for(result)
end

# A duplicate names the prop it collided on, so the ambiguity is confined:
# the duplicate error taints that prop, silencing exactly the checks that
# would read the value nobody can safely pick.
test "a duplicated key silences only the checks that read it" do
	ran = []
	klass = Class.new(Literal::Data) do
		prop :name, String
		prop :age, Integer
	end
	klass.check(:name, "never reported") { |name:| ran << :name; true }
	klass.check(:age, "must be positive") { |age:| ran << :age; age.positive? }

	result = Literal::Draft(klass).check({ "name" => "Ada", :name => "Ada", :age => -1 })

	assert_includes errors_for(result), [:name, "was given more than once"]
	assert_includes errors_for(result), [:age, "must be positive"]
	assert_equal [:age], ran
end

# --- input guarding ---

test "input that is not a Hash raises" do
	[nil, "junk", 42, [1, 2]].each do |input|
		error = assert_raises(Literal::ArgumentError) { Literal::Draft(Person).check(input) }

		assert error.message.include?(input.class.name)
	end
end

# A key that is neither Symbol nor String cannot go in `prop`, so it is filed
# against the value as a whole and the message names it.
test "a key that cannot name a prop is reported against no prop" do
	result = Literal::Draft(Person).check({ 1 => "x", **valid_props })

	assert_equal [[nil, "1 is not a known field"]], errors_for(result)
	assert_equal [], result.error!.errors.fetch(0).path
end

test "a key that cannot name a prop is reported inside a nested Hash too" do
	result = Literal::Draft(Person).check(valid_props(account: { 1 => "x", "name" => "Initech" }))

	assert_equal [[:account, "1 is not a known field"]], errors_for(result)
	assert_equal [:account], result.error!.errors.fetch(0).path
end

# --- built values ---

# A writer enforces the checks its property is part of, so an object cannot
# drift out of its shape's invariant — and the write does not half-happen
# either.
test "a writer refuses a value that breaks a check, and leaves the old one" do
	klass = Class.new(Literal::Struct) do
		prop :name, String
		check(:name, "must be filled") { |name:| !name.empty? }
	end
	object = klass.new(name: "Ada")

	assert_raises(Literal::CheckError) { object.name = "" }
	assert_equal "Ada", object.name
end

# A built value is taken on the strength of its construction, exactly as `new`
# takes it — a value mutated in place afterwards included.
test "Draft.check takes a drifted instance as new would" do
	child_class = Class.new(Literal::Struct) do
		prop :tags, _Array(String), reader: :public
		check(:tags, "must not be empty") { |tags:| !tags.empty? }
	end
	parent_class = Class.new(Literal::Struct) do
		prop :child, child_class
	end
	child = child_class.new(tags: ["a"])
	child.tags.clear

	assert parent_class.new(child:)
	assert Literal::Draft(parent_class).check(child:).success?
end

test "a valid nested instance stays the same object" do
	account = Account.new(name: "Initech")

	person = Literal::Draft(Person).new(**valid_props(account:)).check.value!

	assert person.account.equal?(account)
end

# An inherited writer enforces the subclass's checks too, because it reads
# `checks` off the instance's own class at the time of the write.
test "an inherited writer enforces the subclass's checks" do
	base = Class.new(Literal::Struct) do
		prop :name, String
		check(:name, "base says blank") { |name:| !name.empty? }
	end
	sub = Class.new(base) do
		check(:name, "sub says short") { |name:| name.size >= 3 }
	end

	instance = sub.new(name: "Ada")

	error = assert_raises(Literal::CheckError) { instance.name = "Jo" }

	assert_equal ["sub says short"], error.errors.errors.map(&:message)
	assert_equal "Ada", instance.name

	# The parent is unaffected by its subclass's check.
	assert_equal "Jo", base.new(name: "Ada").tap { |value| value.name = "Jo" }.name
end

# --- shape context for coercions and defaults ---

test "a coercion may call the shape's own methods" do
	klass = Class.new(Literal::Data) do
		prop(:name, String) { |value| presentable(value) }

		private def presentable(value) = value.to_s.strip
	end

	assert_equal "Ada", Literal::Draft(klass).new(name: " Ada ").check.value!.name
end

test "a default may call the shape's own methods" do
	klass = Class.new(Literal::Data) do
		prop :role, String, default: -> { default_role }

		private def default_role = "member"
	end

	assert_equal "member", Literal::Draft(klass).new.check.value!.role
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
	assert_equal 5, Literal::Draft(klass).new(currency: "GBP", amount: "5").check.value!.amount
	assert_equal 5, Literal::Draft(klass).check({ "currency" => "GBP", "amount" => "5" }).value!.amount
end

test "a default reading an earlier property agrees with new" do
	klass = Class.new(Literal::Data) do
		prop :name, String, reader: :public
		prop :email, String, default: -> { "#{name.downcase}@corp.com" }
	end

	assert_equal "ada@corp.com", klass.new(name: "Ada").email
	assert_equal "ada@corp.com", Literal::Draft(klass).check({ name: "Ada" }).value!.email
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

	assert_equal [[:name, "must be a string"]], errors_for(Literal::Draft(klass).check({ name: 42 }))
end

# On sound input, the same raise is the shape's own bug, and it propagates
# exactly as it does out of new.
test "a default that raises on sound input still raises" do
	klass = Class.new(Literal::Data) do
		prop :email, String, default: -> { raise "broken default" }
	end

	error = assert_raises(RuntimeError) { Literal::Draft(klass).check({}) }

	assert_equal "broken default", error.message
end

# The context is per draft: checking works on a copy, and that copy must not
# write resolved defaults onto an object the caller's draft still shares.
test "checking a draft leaves its context untouched" do
	klass = Class.new(Literal::Data) do
		prop :sku, String
		prop :qty, Integer, default: -> { 7 }
	end
	draft = Literal::Draft(klass).new(sku: "x")
	context = draft.__context__

	assert draft.sound?
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

# --- the two soft paths ---

# A wrong type is the difference between them: building the draft goes through
# its own writers, so a wrong value raises there exactly where `new` does.
test "a draft raises a wrong type, where Draft.check reports it" do
	assert_raises(Literal::TypeError) { Person.new(**valid_props(name: 123)) }
	assert_raises(Literal::TypeError) do
		Literal::Draft(Person).new(id: "per_1", name: 123, account: Account.new(name: "Initech")).check
	end

	assert_equal [[:name, "must be a string"]], errors_for(Literal::Draft(Person).check(valid_props(name: 123)))
end

# The draft's initializer has the shape's own signature, so a key that names no
# prop is an unknown keyword rather than a field to report.
test "a draft raises an unknown keyword, where Draft.check reports it" do
	assert_raises(ArgumentError) do
		Literal::Draft(Person).new(id: "per_1", name: "Ada", account: Account.new(name: "Initech"), surprise: 1).check
	end

	assert_equal [[:surprise, "is not a known field"]], errors_for(Literal::Draft(Person).check(valid_props(surprise: 1)))
end

# A draft slot holds a built value or a nested draft, never a Hash, so building a
# nested shape from one is the props form's leniency and not the draft's.
test "a draft raises a nested Hash, where Draft.check builds it" do
	assert_raises(Literal::TypeError) do
		Literal::Draft(Person).new(id: "per_1", name: "Ada", account: { name: "Initech" }).check
	end

	assert_equal "Initech", Literal::Draft(Person).check(valid_props).value!.account.name
end

# Only the type pass belongs to the draft. The checks are what either form is
# for, so a check failure is still collected rather than raised.
test "Draft#check collects a check failure rather than raising it" do
	result = Literal::Draft(Person).new(id: "per_1", name: "Bartholomew", account: Account.new(name: "Initech")).check

	assert_equal [[:name, "must be between 1 and 10 characters"]], errors_for(result)
end

# A draft takes the same signature as `new`, not a Hash of props: a positional
# prop, a splat and a block prop all reach it the way they reach the initializer.
test "a draft checks what it was built from, taking the arguments new takes" do
	klass = Class.new(Literal::Data) do
		prop :first, String, :positional
		prop :rest, _Array(String), :*
		prop :handler, _Nilable(Proc), :&
	end

	# One Proc for both calls, so the two values compare equal rather than
	# differing by which block object each captured.
	handler = -> (value) { value }

	built = klass.new("a", "b", "c", &handler)
	checked = Literal::Draft(klass).new("a", "b", "c", &handler).check.value!

	assert_equal built, checked
	assert_equal "a", checked.first
	assert_equal ["b", "c"], checked.rest
	assert_equal handler, checked.handler
	assert Proc === Literal::Draft(klass).new("a") { |value| value }.check.value!.handler
end

# --- type pass ---

test "reports every bad prop, not just the first" do
	result = Literal::Draft(Person).check(id: 1, name: 2, account: { name: "Initech" })

	assert result.failure?
	assert_equal [[:id, "must be a string"], [:name, "must be a string"]], errors_for(result).sort
end

test "reports a missing required prop" do
	result = Literal::Draft(Person).check(name: "Ada", account: { name: "Initech" })

	assert_equal [[:id, "is missing"]], errors_for(result)
end

test "does not require a prop that has a default or is nilable" do
	assert Literal::Draft(Person).check(valid_props).success?
end

# `new` collects a splat into an empty Array or Hash rather than treating it as
# missing, so the soft path resolves it the same way. `Property#default?` answers
# true for a splat while its `default` is nil, so it cannot go through the
# defaulting branch.
test "resolves an omitted splat the way new does" do
	klass = Class.new(Literal::Data) do
		prop :first, String
		prop :rest, _Array(String), :*
		prop :opts, _Hash(Symbol, String), :**
	end

	value = Literal::Draft(klass).new(first: "a").check.value!

	assert_equal [], value.rest
	assert_equal({}, value.opts)
end

test "a splat resolves the same way from a draft and from props" do
	klass = Class.new(Literal::Data) do
		prop :first, String
		prop :rest, _Array(String), :*
	end

	assert_equal [], Literal::Draft(klass).new(first: "a").check.value!.rest
	assert_equal [], Literal::Draft(klass).check(first: "a").value!.rest
end

test "describes a nilable prop by what it must be, not by its nilability" do
	result = Literal::Draft(Person).check(valid_props(nickname: 42))

	assert_equal [[:nickname, "must be a string"]], errors_for(result)
end

# A coercion block runs on assignment, so the raw value is not what gets checked.
test "a coercing prop coerces a raw value that does not fit" do
	klass = Class.new(Literal::Data) do
		prop(:limit, Integer) { |v| (String === v) ? (Integer(v, exception: false) || v) : v }
	end

	assert_equal 25, Literal::Draft(klass).new(limit: "25").check.value!.limit
	assert_equal 25, Literal::Draft(klass).new(limit: 25).check.value!.limit
end

test "a coercing prop whose value will not coerce is reported" do
	klass = Class.new(Literal::Data) do
		prop(:limit, Integer) { |v| (String === v) ? (Integer(v, exception: false) || v) : v }
	end

	result = Literal::Draft(klass).check(limit: "abc")

	assert_equal [[:limit, "must be an integer"]], result.error!.errors.map { |error| [error.prop, error.message] }
end

test "a coercion that raises reads as a type failure on its prop" do
	klass = Class.new(Literal::Data) do
		prop(:limit, Integer) { |v| Integer(v) }
	end

	assert_equal [[:limit, "must be an integer"]], Literal::Draft(klass).check(limit: "abc").error!.errors.map { |error| [error.prop, error.message] }
	assert_equal 25, Literal::Draft(klass).new(limit: "25").check.value!.limit
end

# The message has to describe whatever failed the type. Describing the raw value
# instead lets a coercion that returns the wrong type contradict itself — a value
# inside the range told it must be in the range.
test "a coercion that returns the wrong type is described by what it returned" do
	klass = Class.new(Literal::Data) do
		prop(:n, _Integer(1..10), &:to_s)
	end

	assert_equal [[:n, "must be an integer"]], errors_for(Literal::Draft(klass).check(n: 5))
end

test "a coerced value that misses a constraint is described by the constraint" do
	klass = Class.new(Literal::Data) do
		prop(:n, _Integer(1..10)) { |value| Integer(value) }
	end

	assert_equal [[:n, "must be between 1 and 10"]], errors_for(Literal::Draft(klass).check(n: "500"))
end

test "a coercion runs once" do
	runs = 0
	counter = -> { runs += 1 }
	klass = Class.new(Literal::Data) do
		prop(:name, String) { |v| counter.call; v.to_s }
	end

	Literal::Draft(klass).new(name: :ada).check

	assert_equal 1, runs
end

test "describes an array prop by its member type" do
	result = Literal::Draft(Person).check(valid_props(tags: "nope"))

	assert_equal [[:tags, "must be an array"]], errors_for(result)
end

test "an array with a bad member is told what each member must be" do
	result = Literal::Draft(Person).check(valid_props(tags: ["ok", 42]))

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
		Literal::Draft(self).check(props).error!.errors.fetch(0).message
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

	assert_equal [[:name, "must be a string"]], errors_for(Literal::Draft(klass).check(name: 42))
end

test "an optional nilable prop reads as what it wraps" do
	klass = Class.new(Literal::Data) do
		prop? :nickname, _Nilable(String)
	end

	assert_equal [[:nickname, "must be a string"]], errors_for(Literal::Draft(klass).check(nickname: 42))
end

# --- the type pass failing is the whole answer ---

# A check is handed values, so it only ever runs against a draft where
# every prop holds one.
test "a type failure returns without running a check" do
	ran = false
	klass = Class.new(Literal::Data) do
		prop :name, String
		check(:name, "never reported") { |name:| ran = true }
	end

	assert Literal::Draft(klass).check(name: 1).failure?
	refute ran
end

test "a missing required prop returns without running a check" do
	ran = false
	klass = Class.new(Literal::Data) do
		prop :a, String
		check(:a, "never reported") { |a:| ran = true }
	end

	result = Literal::Draft(klass).check({})

	assert_equal [[:a, "is missing"]], result.error!.errors.map { |error| [error.prop, error.message] }
	refute ran
end

test "a bad prop silences only the checks that read it" do
	bad = Literal::Draft(Person).check(id: 1, name: "Bartholomew", account: { name: "Initech" })
	assert_equal [[:id, "must be a string"], [:name, "must be between 1 and 10 characters"]], errors_for(bad)

	good = Literal::Draft(Person).check(id: "per_1", name: "Bartholomew", account: { name: "Initech" })
	assert_equal [[:name, "must be between 1 and 10 characters"]], errors_for(good)
end

test "a check reads an omitted nilable prop as the nil the object will hold" do
	seen = :never_ran
	klass = Class.new(Literal::Data) do
		prop :name, String
		prop :nickname, _Nilable(String)
		check(:nickname, "never reported") { |nickname:| seen = nickname; true }
	end

	assert Literal::Draft(klass).new(name: "Ada").check.success?
	assert seen.nil?
end

# Checks are independent of one another: every one whose reads survived the type
# pass runs, so a failure holds nothing back and the caller learns all of it at
# once.
test "every check over one property reports, and the whole-value one too" do
	klass = Class.new(Literal::Data) do
		prop :name, String

		check(:name, "one") { |name:| false }
		check(:name, "two") { |name:| false }
		check("three") { |name:| false }
	end

	errors = Literal::Draft(klass).new(name: "Ada").check.error!.errors.map { |error| [error.prop, error.message] }

	assert_equal [[:name, "one"], [:name, "two"], [nil, "three"]], errors
end

# A check failure files an error and nothing more — the property it is filed
# against is still a value the next check may read and judge.
test "a check reads a property an earlier check reported against" do
	seen = :never
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		check(:max, "must be greater than %{min}") { |max:, min:| max > min }
		check(:max, "must not be one") { |max:| seen = max; max != 1 }
	end

	assert_equal(
		[[:max, "must be greater than 5"], [:max, "must not be one"]],
		errors_for(Literal::Draft(klass).new(min: 5, max: 1).check)
	)
	assert_equal 1, seen
end

# A writer judges the same way: it narrows to the checks that read the written
# property, and every one of them answers.
test "a writer reports every check that reads the written property" do
	seen = :never
	klass = Class.new(Literal::Struct) do
		prop :min, Integer
		prop :max, Integer

		check(:max, "must be greater than %{min}") { |max:, min:| max > min }
		check(:max, "must not be written past 9") { |max:, min:| seen = [min, max]; min < 10 }
	end
	object = klass.new(min: 1, max: 5)
	seen = :never

	error = assert_raises(Literal::CheckError) { object.min = 10 }

	assert_equal ["must be greater than 10", "must not be written past 9"], error.errors.errors.map(&:message)
	assert_equal [10, 5], seen
	assert_equal 1, object.min
end

# A whole-value failure is filed against no property at all, so it carries no
# prop of its own while a property's failure carries one.
test "a whole-value failure sits alongside a property's own" do
	klass = Class.new(Literal::Data) do
		prop :name, String

		check("one") { |name:| false }
		check(:name, "two") { |name:| false }
	end

	errors = Literal::Draft(klass).new(name: "Ada").check.error!.errors.map { |error| [error.prop, error.message] }

	assert_equal [[nil, "one"], [:name, "two"]], errors
end

test "checks run in declaration order, and their failures come back in it" do
	order = []
	klass = Class.new(Literal::Data) do
		prop :name, String

		check(:name, "one") { |name:| order << :first; false }
		check(:name, "two") { |name:| order << :second }
		check(:name, "three") { |name:| order << :third; false }
	end

	errors = Literal::Draft(klass).new(name: "Ada").check.error!.errors.map(&:message)

	assert_equal %i[first second third], order
	assert_equal ["one", "three"], errors
end

test "construction reports every failing check, not just the first" do
	klass = Class.new(Literal::Data) do
		prop :name, String

		check(:name, "one") { |name:| false }
		check(:name, "two") { |name:| false }
	end

	error = assert_raises(Literal::CheckError) { klass.new(name: "Ada") }

	assert_equal ["one", "two"], error.errors.errors.map(&:message)
end

test "a failure carries the validation errors" do
	errors = Literal::Draft(Person).check(valid_props(id: 1)).error!

	assert Literal::Checks::Errors === errors
	assert_equal [[:id, "must be a string"]], errors.errors.map { |error| [error.prop, error.message] }
end

# --- the checks pass ---

test "runs a single-prop check against the built value" do
	result = Literal::Draft(Person).check(valid_props(name: "Bartholomew"))

	assert_equal [[:name, "must be between 1 and 10 characters"]], errors_for(result)
end

test "an error about the whole value is filed with no prop" do
	result = Literal::Draft(Person).check(valid_props(name: "Joe", account: { name: "ACME" }))

	assert_equal [[nil, "name can't be Joe when account is ACME"]], errors_for(result)
end

test "a property check and a whole-value check each answer for themselves" do
	klass = Class.new(Literal::Data) do
		prop :name, String

		check(:name, "must be filled") { |name:| !name.empty? }
		check("must not be Jo") { |name:| name != "Jo" }
	end

	assert_equal [[:name, "must be filled"]], errors_for(Literal::Draft(klass).new(name: "").check)
	assert_equal [[nil, "must not be Jo"]], errors_for(Literal::Draft(klass).new(name: "Jo").check)
	assert Literal::Draft(klass).new(name: "Ada").check.success?
end

# --- the reporting form ---

# `checks` hands the block a reporter and the values it names, and the block
# files whatever it finds — so one block can say more than one thing, and say
# it about whichever property the caller should fix.
test "a reporting check files against a property" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		checks do |errors, min:, max:|
			errors.add(:min, "must not be greater than max (#{max})") if min > max
		end
	end

	assert_equal [[:min, "must not be greater than max (1)"]], errors_for(Literal::Draft(klass).new(min: 5, max: 1).check)
	assert Literal::Draft(klass).new(min: 1, max: 5).check.success?
end

test "a reporting check files about the value as a whole" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		checks do |errors, min:, max:|
			errors.add("#{min} to #{max} is not a span") unless max > min
		end
	end

	assert_equal [[nil, "5 to 1 is not a span"]], errors_for(Literal::Draft(klass).new(min: 5, max: 1).check)
end

test "one reporting check files as many failures as it finds" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		checks do |errors, min:, max:|
			errors.add(:min, "must not be negative") if min.negative?
			errors.add(:max, "must not be negative") if max.negative?
			errors.add("must span something") if min == max
		end
	end

	assert_equal(
		[[:min, "must not be negative"], [:max, "must not be negative"], [nil, "must span something"]],
		errors_for(Literal::Draft(klass).new(min: -1, max: -1).check)
	)
end

# A shape declares as many as it needs, and they are checks like any other: all
# of them run, whatever the others found, and their failures come back in
# declaration order.
test "every reporting check on a shape runs and reports in declaration order" do
	ran = []
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		checks do |errors, min:|
			ran << :first
			errors.add(:min, "must not be negative") if min.negative?
		end

		checks do |errors, min:, max:|
			ran << :second
			errors.add(:max, "must be greater than min") unless max > min
		end

		checks do |errors, max:|
			ran << :third
			errors.add("cannot describe a negative span") if max.negative?
		end
	end

	assert_equal(
		[[:min, "must not be negative"], [:max, "must be greater than min"], [nil, "cannot describe a negative span"]],
		errors_for(Literal::Draft(klass).new(min: -1, max: -2).check)
	)
	assert_equal [:first, :second, :third], ran
end

# `add` answers nil, so a block whose last statement is a conditional `add`
# cannot be mistaken for a predicate returning false.
test "add answers nil" do
	seen = :never
	klass = Class.new(Literal::Data) do
		prop :n, Integer

		checks do |errors, n:|
			seen = errors.add(:n, "must be positive") unless n.positive?
		end
	end

	assert Literal::Draft(klass).new(n: 1).check.success?
	assert_equal [[:n, "must be positive"]], errors_for(Literal::Draft(klass).new(n: -1).check)
	assert seen.nil?
end

# The block interpolates its own message, so there is nothing left for `%{}`
# to fill and a literal one passes through as the text it is.
test "a reporting check's message is not slot filled" do
	klass = Class.new(Literal::Data) do
		prop :n, Integer

		checks do |errors, n:|
			errors.add(:n, "must be positive, not %{n}")
		end
	end

	assert_equal [[:n, "must be positive, not %{n}"]], errors_for(Literal::Draft(klass).new(n: 1).check)
end

# The two forms are checks like any other, so both run and both report.
test "a predicate check and a reporting check both report in one result" do
	klass = Class.new(Literal::Data) do
		prop :name, String

		check(:name, "must be filled") { |name:| !name.strip.empty? }

		checks do |errors, name:|
			errors.add(:name, "must not be padded") if name != name.strip
		end
	end

	assert_equal(
		[[:name, "must be filled"], [:name, "must not be padded"]],
		errors_for(Literal::Draft(klass).new(name: " ").check)
	)
end

# An undefinable property that was not given holds no value, so a reporting
# check reading one does not apply either.
test "a reporting check reading an ungiven undefinable prop does not apply" do
	ran = false
	klass = Class.new(Literal::Data) do
		prop :a, Integer
		prop? :b, Integer

		checks do |errors, b:|
			ran = true
			errors.add(:b, "must be positive") unless b.positive?
		end
	end

	assert Literal::Draft(klass).new(a: 1).check.success?
	refute ran
	assert_equal [[:b, "must be positive"]], errors_for(Literal::Draft(klass).check({ a: 1, b: -1 }))
end

# A writer enforces a reporting check the same way, narrowing to the ones that
# read the property being written.
test "a writer enforces a reporting check that reads its property" do
	klass = Class.new(Literal::Struct) do
		prop :min, Integer
		prop :max, Integer

		checks do |errors, min:, max:|
			errors.add(:max, "must be greater than min") unless max > min
		end
	end
	span = klass.new(min: 1, max: 5)

	assert_raises(Literal::CheckError) { span.min = 10 }
	assert_equal 1, span.min

	span.max = 9

	assert_equal 9, span.max
end

# --- reporting guards ---

# A property the shape does not have is the check's own bug, so `add` raises
# rather than filing an error nobody could read.
test "add raises for a property the shape does not have" do
	klass = Class.new(Literal::Data) do
		prop :n, Integer

		checks { |errors, n:| errors.add(:nope, "…") }
	end

	error = assert_raises(Literal::ArgumentError) { klass.new(n: 1) }

	assert(/has no :nope property for a check to report against/.match?(error.message))
end

test "add raises for a message that is not a String" do
	klass = Class.new(Literal::Data) do
		prop :n, Integer

		checks { |errors, n:| errors.add(:n, :nope) }
	end

	error = assert_raises(Literal::ArgumentError) { klass.new(n: 1) }

	assert_equal "A check's message is a String, got Symbol", error.message
end

# The reporter comes first and every read is a keyword, which is what keeps the
# two apart at a glance.
test "a reporting check whose first parameter is a keyword is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			checks { |min:| false }
		end
	end

	assert(/takes the reporter first/.match?(error.message))
end

test "a reporting check reading a property positionally is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			checks { |errors, min| false }
		end
	end

	assert(/cannot take :opt/.match?(error.message))
end

# The reporter alone reads nothing, so there is nothing to judge.
test "a reporting check that reads nothing is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			checks { |errors| false }
		end
	end

	assert(/takes at least one/.match?(error.message))
end

test "a reporting check reading a property the shape does not have is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			checks { |errors, nope:| false }
		end
	end

	assert(/has no :nope property for a check to read/.match?(error.message))
end

# The block is the check, so there is nothing for `checks` to declare without one.
test "checks raises without a block" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			checks
		end
	end

	assert_equal "checks requires a block", error.message
end

# --- what a check reads ---

# A check names the properties it reads by its keyword parameters, and is
# handed their values — never the object — so it asks nothing of the shape.
test "a predicate is handed the values of the properties it names" do
	seen = nil
	klass = Class.new(Literal::Data) do
		prop :name, String
		prop :age, Integer
		check(:name, "never reported") { |name:, age:| seen = [name, age]; true }
	end

	assert Literal::Draft(klass).new(name: "Ada", age: 36).check.success?
	assert_equal ["Ada", 36], seen
end

# The one-property case names it and nothing else, and files the failure
# against the same property it read.
test "a keyword reads the property the error is reported against" do
	klass = Class.new(Literal::Data) do
		prop :name, String
		prop :age, Integer
		check(:age, "must be an adult") { |age:| age >= 18 }
	end

	assert_equal [[:age, "must be an adult"]], errors_for(Literal::Draft(klass).new(name: "Ada", age: 12).check)
	assert Literal::Draft(klass).new(name: "Ada", age: 18).check.success?
end

# A predicate may read more than one property while the failure is still
# reported against the one the caller should fix.
test "a predicate reads two properties and reports against one" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		check(:max, "must be greater than min") { |max:, min:| max > min }
	end

	assert_equal [[:max, "must be greater than min"]], errors_for(Literal::Draft(klass).new(min: 5, max: 1).check)
	assert Literal::Draft(klass).new(min: 1, max: 5).check.success?
end

# A message's %{name} slots are filled with the values the predicate judged, so
# a message can name what it saw.
test "a message interpolates the values the predicate judged" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		check(:max, "must be greater than %{min}") { |max:, min:| max > min }
	end

	assert_equal [[:max, "must be greater than 5"]], errors_for(Literal::Draft(klass).new(min: 5, max: 1).check)
end

test "a whole-value message interpolates too" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		check("%{min} to %{max} is not a span") { |min:, max:| max > min }
	end

	assert_equal [[nil, "5 to 1 is not a span"]], errors_for(Literal::Draft(klass).new(min: 5, max: 1).check)
end

# Only %{name} is a slot: a literal percent sign — "100%", "% off" — passes
# through untouched, unlike format-string interpolation.
test "a message without slots keeps its percent signs" do
	klass = Class.new(Literal::Data) do
		prop :rate, Integer
		check(:rate, "must be under 100%") { |rate:| rate < 100 }
	end

	assert_equal [[:rate, "must be under 100%"]], errors_for(Literal::Draft(klass).new(rate: 150).check)
end

# A slot names a property, and property names are not confined to ASCII.
test "a slot fills a non-ASCII property name" do
	klass = Class.new(Literal::Data) do
		prop :größe, Integer
		check(:größe, "%{größe} is too big") { |größe:| größe < 10 }
	end

	assert_equal [[:größe, "42 is too big"]], errors_for(Literal::Draft(klass).new(:größe => 42).check)
end

# A value's to_s is spliced in verbatim — gsub's replacement conventions do not
# apply to it, and a value that happens to contain a slot is not re-expanded.
test "an interpolated value is not itself interpreted" do
	klass = Class.new(Literal::Data) do
		prop :name, String
		check(:name, "%{name} is reserved") { |name:| name != "\\1 %{name}" }
	end

	assert_equal [[:name, "\\1 %{name} is reserved"]], errors_for(Literal::Draft(klass).new(name: "\\1 %{name}").check)
end

# The message is checked once, at declaration — so the check keeps its own
# copy, or the caller could mutate an unfillable slot in after the check.
test "a message mutated after declaration keeps its checked form" do
	message = +"must be positive"

	klass = Class.new(Literal::Data) do
		prop :count, Integer
		check(:count, message) { |count:| count > 0 }
	end

	message << " (max %{max})"

	assert_equal [[:count, "must be positive"]], errors_for(Literal::Draft(klass).new(count: -1).check)
end

# The parameter names are the shape's own property names, so a name it does not
# have is a mistake in the check, not a check failure. It is caught where it is
# written rather than on the first value that reaches it.
test "reading a property the shape does not have raises at declaration time" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			check(:name, "…") { |nope:| nope }
		end
	end

	assert(/nope/.match?(error.message))
end

# Values are read out of storage, so a check works on a shape that declares
# no readers at all.
test "a shape with no readers is still checked" do
	klass = Class.new(Literal::Data) do
		prop :name, String, reader: false
		prop :age, Integer, reader: false
		check(:age, "must be an adult") { |age:, name:| name.empty? || age >= 18 }
	end

	refute klass.new(name: "Ada", age: 36).respond_to?(:name)
	assert_equal [[:age, "must be an adult"]], errors_for(Literal::Draft(klass).new(name: "Ada", age: 12).check)
end

test "a check reads a defaulted prop as the value the object will carry" do
	klass = Class.new(Literal::Data) do
		prop :limit, Integer, default: -> { 10 }
		check(:limit, "saw %{limit}") { |limit:| limit < 5 }
	end

	assert_equal [[:limit, "saw 10"]], Literal::Draft(klass).new.check.error!.errors.map { |error| [error.prop, error.message] }
end

# `Draft.check` mirrors `from_props`: one Hash of property values, so a
# caller holding untrusted input has nothing to splat. It declares no keywords of
# its own, so keywords written at the call site arrive as that Hash.
test "takes the props as a Hash, written as one or as keywords" do
	props = { id: "per_1", name: "Ada", account: { name: "Initech" } }

	assert Literal::Draft(Person).check(props).success?
	assert Literal::Draft(Person).check(id: "per_1", name: "Ada", account: { name: "Initech" }).success?
end

test "a draft with nothing assigned checks when every prop can default" do
	klass = Class.new(Literal::Data) do
		prop :role, String, default: -> { "member" }
	end

	assert_equal "member", Literal::Draft(klass).new.check.value!.role
end

test "uses the current prop shape after the class changes" do
	klass = Class.new(Literal::Data) do
		prop :name, String
	end

	assert Literal::Draft(klass).new(name: "Ada").check.success?

	klass.prop :age, Integer

	person = Literal::Draft(klass).new(name: "Ada", age: 42).check.value!
	assert_equal 42, person.age
end

# --- nested ---

test "checks a Hash for a Data prop by that type's own checks" do
	result = Literal::Draft(Person).check(valid_props(account: { name: "  " }))

	assert_equal [[:account, "must not be blank"]], errors_for(result)
end

# A nested value's own failure taints the prop that held it, so a check reading
# it never judges a value already known to be invalid — while checks about
# sound props still speak.
test "a nested value's own failure silences only its readers" do
	result = Literal::Draft(Person).check(id: "aaa", name: "", account: { name: "" })

	assert_equal(
		[[:account, "must not be blank"], [:name, "must be between 1 and 10 characters"]],
		errors_for(result)
	)
end

# The nested error carries the whole route, while `prop` stays the top-level
# property that held it, so an existing renderer keyed on `prop` keeps working.
test "a nested error keeps the full path under the prop that held it" do
	result = Literal::Draft(Person).check(id: "aaa", name: "Ada", account: { name: "" })

	error = result.error!.errors.fetch(0)

	assert_equal %i[account name], error.path
	assert_equal :account, error.prop
end

test "this level's own error keeps its own path" do
	result = Literal::Draft(Person).check(valid_props(name: ""))

	error = result.error!.errors.fetch(0)

	assert_equal [:name], error.path
	assert_equal :name, error.prop
end

test "a check never reads a nested value that failed its own checks" do
	ran = false
	outer = Class.new(Literal::Data) do
		prop :account, Account
		check(:account, "never reported") { |account:| ran = true }
	end

	result = Literal::Draft(outer).check(account: { name: "" })

	refute ran
	assert_equal [[:account, "must not be blank"]], errors_for(result)
end

# With the nested value sound, this level's checks do run and can read it.
test "a check reads a nested value that passed its own checks" do
	seen = :never_ran
	outer = Class.new(Literal::Data) do
		prop :account, Account
		check(:account, "must not be Initech") { |account:| seen = account; account.name != "Initech" }
	end

	result = Literal::Draft(outer).check(account: { name: "Initech" })

	assert Account === seen
	assert_equal "Initech", seen.name
	assert_equal [[:account, "must not be Initech"]], errors_for(result)
end

# A nested check failure taints the prop that held it, so this level's checks
# that read it never run against a value already known invalid.
test "a nested check failure silences this level's readers of it" do
	inner = Class.new(Literal::Data) do
		prop :name, String
		prop :code, String

		check(:code, "bad code") { |code:| code != "bad" }
	end

	outer = Class.new(Literal::Data) do
		prop :inner, inner

		check("never reported") { |inner:| inner.name.empty? }
	end

	result = Literal::Draft(outer).check(inner: { name: "ada", code: "bad" })

	assert_equal(
		[[:inner, "bad code"]],
		result.error!.errors.map { |error| [error.prop, error.message] }
	)
end

test "a nested type failure does hold the checks back, leaving nothing to read" do
	ran = false
	outer = Class.new(Literal::Data) do
		prop :account, Account
		check(:account, "never reported") { |account:| ran = true }
	end

	result = Literal::Draft(outer).check(account: { name: 42 })

	assert_equal [[:account, "must be a string"]], result.error!.errors.map { |error| [error.prop, error.message] }
	refute ran
end

test "a nested check failure skips the checks that read it, not the rest" do
	ran = :never
	klass = Class.new(Literal::Data) do
		prop :account, Account
		prop :name, String

		check("never reported") { |account:| ran = account; false }
		check(:name, "too short") { |name:| name.size > 3 }
	end

	result = Literal::Draft(klass).check(account: { name: "" }, name: "Jo")

	assert_equal :never, ran
	assert_equal [[:account, "must not be blank"], [:name, "too short"]], errors_for(result)
end

test "surfaces a nested type error under the prop that held it" do
	result = Literal::Draft(Person).check(valid_props(account: { name: 42 }))

	assert_equal [[:account, "must be a string"]], errors_for(result)
end

test "carries the full path so a nested field can be placed exactly" do
	result = Literal::Draft(Person).check(valid_props(account: { name: 42 }))

	assert_equal [%i[account name]], result.error!.errors.map(&:path)
end

test "a top-level error's path is the prop itself, a whole-value error none" do
	typed = Literal::Draft(Person).check(valid_props(id: 1)).error!.errors.fetch(0)
	assert_equal [:id], typed.path

	based = Literal::Draft(Person).check(valid_props(name: "Joe", account: { name: "ACME" })).error!.errors.fetch(0)
	assert based.path.empty?
end

test "accepts string keys inside a nested Hash" do
	assert Literal::Draft(Person).check(valid_props(account: { "name" => "Initech" })).success?
end

test "accepts string keys at the top level" do
	props = { "id" => "per_1", "name" => "Ada", "account" => { "name" => "Initech" } }

	assert Literal::Draft(Person).check(props).success?
end

# A HashWithIndifferentAccess's `transform_keys` answers another
# HashWithIndifferentAccess, which re-stringifies the interned Symbols — so
# interning has to build a plain Hash, or every field reads as unknown.
test "accepts a HashWithIndifferentAccess at the top level" do
	props = ActiveSupport::HashWithIndifferentAccess.new(
		id: "per_1", name: "Ada", account: { name: "Initech" },
	)

	assert Literal::Draft(Person).check(props).success?
end

test "accepts a HashWithIndifferentAccess inside a nested prop" do
	props = valid_props(account: ActiveSupport::HashWithIndifferentAccess.new(name: "Initech"))

	assert Literal::Draft(Person).check(props).success?
end

test "reports an unknown key inside a nested Hash under the prop that held it" do
	result = Literal::Draft(Person).check(valid_props(account: { name: "Initech", junk: 1 }))

	assert_equal [[:account, "is not a known field"]], errors_for(result)
	assert_equal %i[account junk], result.error!.errors.fetch(0).path
end

# The unchecked branch reports by name too, rather than letting `new` raise
# about only the first of them.
test "reports an unknown key inside a nested Data that has no checks" do
	result = Literal::Draft(Person).check(valid_props(address: { city: "London", junk: 1 }))

	assert_equal [[:address, "is not a known field"]], errors_for(result)
	assert_equal %i[address junk], result.error!.errors.fetch(0).path
end

test "builds a nested Data that has no checks of its own" do
	person = Literal::Draft(Person).check(valid_props(address: { city: "London" })).value!

	assert_equal "London", person.address.city
end

# The shape's class name is not part of the message — it may be internal — but
# the field that failed is.
test "names the bad field of a nested Data with no checks of its own" do
	result = Literal::Draft(Person).check(valid_props(address: { city: 42 }))

	assert_equal [[:address, "must be a string"]], errors_for(result)
	assert_equal %i[address city], result.error!.errors.fetch(0).path
end

test "takes an already-built nested instance as readily as a Hash" do
	result = Literal::Draft(Person).new(**valid_props(account: Account.new(name: "Initech"))).check

	assert result.success?
end

# Every construction path enforces the checks, so an instance that exists already
# satisfies them. Nested checking trusts it rather than paying to re-check.
test "a nested instance is trusted, because it cannot have been built invalid" do
	assert_raises(Literal::CheckError) { Account.new(name: "   ") }
	assert Literal::Draft(Person).new(**valid_props(account: Account.new(name: "Initech"))).check.success?
end

test "a nested prop's coercion runs before nested checking" do
	inner = Class.new(Literal::Data) do
		prop :name, String
		check(:name, "must not be blank") { |name:| !name.empty? }
	end
	outer = Class.new(Literal::Data) do
		prop(:inner, inner) { |value| (Hash === value) ? inner.new(name: value[:wire_name].to_s) : value }
	end

	assert_equal "Ada", Literal::Draft(outer).check(inner: { wire_name: "Ada" }).value!.inner.name
	assert_equal(
		[[:inner, "must not be blank"]],
		Literal::Draft(outer).check(inner: { wire_name: "" }).error!.errors.map { |error| [error.prop, error.message] }
	)
end

# The common wire coercion normalizes keys and leaves the nested shape to build
# itself, so what the coercion returns has to reach nested checking as the
# Hash it is.
test "a nested prop's coercion may hand nested checking a Hash" do
	inner = Class.new(Literal::Data) do
		prop :name, String
		check(:name, "must not be blank") { |name:| !name.empty? }
	end
	outer = Class.new(Literal::Data) do
		prop(:inner, inner) { |value| (Hash === value) ? value.transform_keys(&:to_sym) : value }
	end

	assert_equal "Initech", Literal::Draft(outer).check(inner: { "name" => "Initech" }).value!.inner.name
	assert_equal [[:inner, "must not be blank"]], errors_for(Literal::Draft(outer).check(inner: { "name" => "" }))
end

test "takes a nested draft as a value and checks it by its shape" do
	account = Literal::Draft(Account).new
	account.name = ""

	result = Literal::Draft(Person).new(**valid_props(account:)).check

	assert_equal [[:account, "must not be blank"]], errors_for(result)

	account.name = "Initech"
	assert Literal::Draft(Person).new(**valid_props(account:)).check.success?
end

test "a draft of the wrong shape is a plain type failure" do
	result = Literal::Draft(Person).check(valid_props(account: Literal::Draft(Address).new))

	assert_equal [[:account, "is not allowed"]], errors_for(result)
end

test "leaves an open Hash prop as the Hash it is" do
	klass = Class.new(Literal::Data) do
		prop :metadata, _Hash(String, String)
	end

	assert_equal({ "a" => "b" }, Literal::Draft(klass).new(metadata: { "a" => "b" }).check.value!.metadata)
end

# --- result plumbing ---

test "handle dispatches the success branch with the instance" do
	seen = nil
	Literal::Draft(Person).check(valid_props).handle do |on|
		on.success { |person| seen = person.name }
		on.failure { raise "expected success" }
	end

	assert_equal "Ada", seen
end

test "handle dispatches the failure branch with the validation errors" do
	seen = nil
	Literal::Draft(Person).check(valid_props(id: 1)).handle do |on|
		on.success { raise "expected failure" }
		on.failure { |errors| seen = errors.errors.size }
	end

	assert_equal 1, seen
end

# --- declaration guards ---

# The predicate is the check, so there is nothing for `check` to declare
# without one.
test "check raises without a block" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			check(:name, "…")
		end
	end

	assert_equal "check requires a block", error.message
end

# A single anonymous parameter — `it`, or a lone `_1` — reads the property the
# failure is filed against, so the common one-property check needs no name.
test "it reads the pinned property" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer

		check(:min, "must not be negative") { !it.negative? } # rubocop:disable Lint/ItWithoutArgumentsInBlock
	end

	assert_equal 1, klass.new(min: 1).min

	error = assert_raises(Literal::CheckError) { klass.new(min: -1) }
	assert error.message.include?("must not be negative")
end

test "a lone _1 reads the pinned property" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer

		check(:min, "must not be negative") { !_1.negative? } # rubocop:disable Style/NumberedParameters
	end

	assert_equal 1, klass.new(min: 1).min
	assert_raises(Literal::CheckError) { klass.new(min: -1) }
end

# `%{}` slots name reads, and the pinned property is the read.
test "it fills the pinned property's message slot" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer

		check(:min, "cannot be %{min}") { !it.negative? } # rubocop:disable Lint/ItWithoutArgumentsInBlock
	end

	error = assert_raises(Literal::CheckError) { klass.new(min: -3) }
	assert error.message.include?("cannot be -3")
end

# A Symbol proc has no parameter names to read from, but it takes exactly one
# value — so like `it`, it reads the property the failure is filed against.
test "a Symbol proc reads the pinned property" do
	klass = Class.new(Literal::Data) do
		prop :count, Integer

		check(:count, "cannot be %{count}", &:positive?)
	end

	assert_equal 1, klass.new(count: 1).count
	assert_equal [[:count, "cannot be 0"]], errors_for(Literal::Draft(klass).new(count: 0).check)

	error = assert_raises(Literal::CheckError) { klass.new(count: -1) }
	assert error.message.include?("cannot be -1")
end

test "a Symbol proc in a whole-value check is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			check("…", &:empty?)
		end
	end

	assert_equal(
		"A whole-value check has no property for an anonymous block to read, so name what it reads: write `{ |min:, max:| ... }`",
		error.message
	)
end

# A whole-value check pins no property, so an anonymous parameter has
# nothing to read.
test "it in a whole-value check is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			check("…") { it.empty? } # rubocop:disable Lint/ItWithoutArgumentsInBlock
		end
	end

	assert_equal(
		"A whole-value check has no property for an anonymous block to read, so name what it reads: write `{ |min:, max:| ... }`",
		error.message
	)
end

# Beyond a lone `_1`, a numbered parameter is a second positional, which names
# nothing to read.
test "a numbered parameter beyond a lone _1 is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			prop :max, Integer
			check(:max, "…") { _1 < _2 } # rubocop:disable Style/NumberedParameters
		end
	end

	assert_equal(
		"A check reads its properties as keywords: write `{ |min:, max:| ... }`, not `{ |min, max| ... }`; a bare `it` reads the property the failure is filed against",
		error.message
	)
end

# Every named read is a keyword, the pinned property included — so a positional
# that carries a name is refused where it is written, rather than quietly
# reading by position what it looks like it reads by name.
test "a named positional parameter is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			check(:min, "…") { |min| min > 0 }
		end
	end

	assert_equal(
		"A check reads its properties as keywords: write `{ |min:, max:| ... }`, not `{ |min, max| ... }`; a bare `it` reads the property the failure is filed against",
		error.message
	)
end

# Including the pinned property: it is read by name like every other read, or
# anonymously and not at all by name.
test "a positional parameter alongside a keyword is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			prop :max, Integer
			check(:max, "…") { |max, min:| max > min }
		end
	end

	assert_equal(
		"A check reads its properties as keywords: write `{ |min:, max:| ... }`, not `{ |min, max| ... }`; a bare `it` reads the property the failure is filed against",
		error.message
	)
end

# A whole-value check reads by keyword like any other, so a positional is
# refused there for the same reason.
test "a named positional in a whole-value check is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			check("…") { |name| name == "" }
		end
	end

	assert_equal(
		"A check reads its properties as keywords: write `{ |min:, max:| ... }`, not `{ |min, max| ... }`; a bare `it` reads the property the failure is filed against",
		error.message
	)
end

# A keyword parameter reads the property it names, in whatever order the block
# writes them — the values arrive by name.
test "keyword parameters read the properties they name" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		check(:max, "must be greater than %{min}") { |min:, max:| max > min }
	end

	assert Literal::Draft(klass).new(min: 1, max: 5).check.success?
	assert_equal [[:max, "must be greater than 5"]], errors_for(Literal::Draft(klass).new(min: 5, max: 1).check)
end

# The pinned property is a read like any other, named or not as the check
# pleases.
test "the pinned property is read as a keyword" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		check(:max, "must be greater than %{min}") { |max:, min:| max > min }
	end

	assert Literal::Draft(klass).new(min: 1, max: 5).check.success?
	assert_equal [[:max, "must be greater than 5"]], errors_for(Literal::Draft(klass).new(min: 5, max: 1).check)
end

# So its own slot fills from that read, exactly as another property's does.
test "a keyword read of the pinned property fills its message slot" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		check(:max, "%{max} must be greater than %{min}") { |max:, min:| max > min }
	end

	assert_equal [[:max, "1 must be greater than 5"]], errors_for(Literal::Draft(klass).new(min: 5, max: 1).check)
end

# And a slot for the pinned property is only fillable when the check reads it,
# so one that does not is refused like any other unread name.
test "a slot for a pinned property the check does not read raises at declaration time" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			prop :max, Integer
			check(:max, "must exceed %{max}") { |min:| min > 0 }
		end
	end

	assert(/does not read :max/.match?(error.message))
end

test "a keyword parameter with a default still reads its property" do
	klass = Class.new(Literal::Data) do
		prop :n, Integer
		check(:n, "must be positive") { |n: 0| n.positive? }
	end

	assert Literal::Draft(klass).new(n: 1).check.success?
	assert_equal [[:n, "must be positive"]], errors_for(Literal::Draft(klass).new(n: -1).check)
end

# A property named after a reserved word is only spellable as a keyword —
# `{ |end| ... }` does not even parse. As a keyword it declares and binds, and
# the body reads the value through the binding.
test "a keyword parameter spells a reserved-word property" do
	klass = Class.new(Literal::Data) do
		prop :begin, Integer
		prop :end, Integer

		check(:end, "must be after %{begin}") { |begin:, end:|
			binding.local_variable_get(:end) > binding.local_variable_get(:begin)
		}
	end

	assert Literal::Draft(klass).new(begin: 1, end: 5).check.success?
	assert_equal [[:end, "must be after 5"]], errors_for(Literal::Draft(klass).new(begin: 5, end: 1).check)
end

test "a keyword parameter naming no property raises at declaration time" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			check(:name, "…") { |nope:| false }
		end
	end

	assert error.message.include?(":nope")
end

# A `**` catch-all names nothing to read, like `*` and `&` before it.
test "a keyword rest parameter is refused" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			check(:name, "…") { |**props| false }
		end
	end

	assert(/cannot take :keyrest/.match?(error.message))
end

# The writer of a property a check reads re-runs it, however the read is
# spelled.
test "a writer enforces a check that reads by keyword" do
	klass = Class.new(Literal::Object) do
		prop :min, Integer, writer: :public
		prop :max, Integer, writer: :public
		check(:max, "must be greater than %{min}") { |min:, max:| max > min }
	end

	instance = klass.new(min: 1, max: 5)
	assert_raises(Literal::CheckError) { instance.min = 10 }
	assert_equal 1, instance.instance_variable_get(:@min)
end

test "a keyword read of an ungiven undefinable property does not apply" do
	klass = Class.new(Literal::Data) do
		prop? :nickname, String
		check(:nickname, "must be short") { |nickname:| nickname.size <= 5 }
	end

	assert Literal::Draft(klass).new.check.success?
	assert_equal [[:nickname, "must be short"]], errors_for(Literal::Draft(klass).new(nickname: "Bartholomew").check)
end

# A predicate with no parameters reads nothing, so it is a constant, not a
# check — and on Ruby 3.3 a bare `it` also reports no parameters, so accepting
# zero would let it through to raise a NameError out of construction there.
test "a predicate with no parameters is refused at declaration" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			check(:name, "is never allowed") { false }
		end
	end

	assert(/at least one/.match?(error.message))
end

# The property a failure is reported against is checked where the check is
# written, not on the first value that reaches it — otherwise a typo sits latent
# and then raises out of every construction of the shape.
test "reporting against a prop the shape does not have raises at declaration time" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :name, String
			check(:nope, "…") { false }
		end
	end

	assert(/nope/.match?(error.message))
end

# --- inheritance ---

# A subclass inherits its parent's props, so it inherits what guards them too.
class Base < Literal::Data
	prop :name, String

	check(:name, "base says blank") { |name:| !name.empty? }
end

class Sub < Base
	prop :extra, _Nilable(String)

	check(:name, "sub says short") { |name:| name.size >= 3 }
end

class SubSub < Sub
	check("subsub says so") { |name:| false }
end

test "a subclass inherits its parent's checks" do
	assert_equal [[:name, "base says blank"]], Literal::Draft(Base).new(name: "").check.error!.errors.map { |error| [error.prop, error.message] }
	assert_includes Literal::Draft(Sub).new(name: "").check.error!.errors.map(&:message), "base says blank"
end

# A subclass's checks sit after its parent's, and answer independently of them.
test "inherited checks run before the subclass's own" do
	assert_equal ["base says blank", "sub says short"], Literal::Draft(Sub).new(name: "").check.error!.errors.map(&:message)
	assert_equal ["sub says short"], Literal::Draft(Sub).new(name: "Jo").check.error!.errors.map(&:message)
end

test "a subclass's own checks do not leak back to its parent" do
	assert_equal ["base says blank"], Literal::Draft(Base).new(name: "").check.error!.errors.map(&:message)
	assert_equal 1, Base.literal_checks.size
	assert_equal 2, Sub.literal_checks.size
end

test "inheritance carries down more than one level" do
	# Only the third level's check fails, so only it speaks.
	assert_equal ["subsub says so"], Literal::Draft(SubSub).new(name: "Ada").check.error!.errors.map(&:message)
	# Every level's fails, and every level's is reported.
	assert_equal(
		["base says blank", "sub says short", "subsub says so"],
		Literal::Draft(SubSub).new(name: "").check.error!.errors.map(&:message)
	)
end

test "a subclass checks the props it added as well as the ones it inherited" do
	assert_equal [[:extra, "must be a string"]], Literal::Draft(Sub).check(name: "Ada", extra: 42).error!.errors.map { |error| [error.prop, error.message] }
end

# Both forms inherit the same way: a subclass adds to whatever its parent
# declared, in either form, and the parent stays as constrained as it was.
test "a subclass adds both forms on top of its parent's" do
	parent = Class.new(Literal::Data) do
		prop :name, String

		check(:name, "parent says uppercase") { |name:| name == name.downcase }

		checks do |errors, name:|
			errors.add(:name, "parent says padded") if name != name.strip
		end
	end

	child = Class.new(parent) do
		check(:name, "child says short") { |name:| name.size >= 5 }

		checks do |errors, name:|
			errors.add(:name, "child says digits") if name.match?(/\d/)
		end
	end

	assert_equal(
		["parent says uppercase", "parent says padded", "child says short", "child says digits"],
		Literal::Draft(child).new(name: " A1").check.error!.errors.map(&:message)
	)
	assert_equal(
		["parent says uppercase", "parent says padded"],
		Literal::Draft(parent).new(name: " A1").check.error!.errors.map(&:message)
	)
	assert_equal 2, parent.literal_checks.size
	assert_equal 4, child.literal_checks.size
end

# A frozen class can still be asked for its checks, it just cannot cache them —
# lazy resolution must not turn the first checked write on a frozen subclass
# into a FrozenError.
test "a frozen subclass still enforces on write" do
	parent = Class.new(Literal::Struct) do
		prop :min, Integer
		prop :max, Integer
		check(:max, "must be greater than min") { |max:, min:| max > min }
	end
	child = Class.new(parent)
	object = child.new(min: 1, max: 5)
	child.freeze

	assert Literal::Draft(child).new(min: 1, max: 5).sound?
	assert_raises(Literal::CheckError) { object.max = 0 }
	assert_equal 5, object.max

	object.max = 9

	assert_equal 9, object.max
end

# Declaring on a frozen shape — an enum after its class body has closed — can
# never install, so it is refused by name rather than left to the bare
# FrozenError the check install would raise.
test "check on a frozen shape raises at the declaration" do
	klass = Class.new(Literal::Data) do
		prop :count, Integer
	end
	klass.freeze

	error = assert_raises(Literal::ArgumentError) do
		klass.check(:count, "must be positive") { |count:| count > 0 }
	end

	assert(/^Cannot declare checks on .*, because it is frozen\.$/.match?(error.message))
end

# As `prop` does: a check added after a subclass exists would leave the subclass
# less constrained than its parent while still passing as it.
test "check on a shape a subclass has inherited raises at the declaration" do
	klass = Class.new(Literal::Data) do
		prop :count, Integer
	end
	Class.new(klass)

	error = assert_raises(Literal::ArgumentError) do
		klass.check(:count, "must be positive") { |count:| count > 0 }
	end

	assert(/^Cannot declare checks on .*, because .* has already inherited them\.$/.match?(error.message))
end

# Checks resolve through the superclass the way literal_properties does, not
# through an inherited hook — a hook is silently lost when a class overrides
# `inherited` without calling super, and the subclass would construct objects
# its parent's invariant forbids.
test "checks survive an inherited override that forgets super" do
	parent = Class.new(Literal::Struct) do
		prop :min, Integer
		check(:min, "must not be negative") { |min:| !min.negative? }

		def self.inherited(subclass); end
	end
	child = Class.new(parent)

	assert_raises(Literal::CheckError) { child.new(min: -1) }
end

# --- the soft path agrees with new ---

# The property that makes this predictable: for any input `new` accepts, the
# soft path must accept it too, and build the same value. It is deliberately
# laxer in what shapes of input it takes — a Hash or draft for a nested prop,
# String keys — but never stricter about the values themselves.
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
	assert Literal::Draft(klass).new(name: +"mutable").check.value!.name.frozen?
end

test "a prop with both a coercion and a seal runs the coercion first" do
	klass = Class.new(Literal::Data) do
		prop :n, _Frozen(String), &(Literal.Coercion(&:to_s) >> Literal.Seal { |value| value.frozen? ? value : value.dup.freeze })
	end

	assert_equal "5", klass.new(n: 5).n
	assert_equal "5", Literal::Draft(klass).new(n: 5).check.value!.n
	assert Literal::Draft(klass).new(n: 5).check.value!.n.frozen?
end

# The initializer coerces a default, so a shape whose default is written in its
# input's terms resolves the same way either way.
test "a default goes through the prop's coercion" do
	klass = Class.new(Literal::Data) do
		prop(:n, Integer, default: -> { "7" }) { |value| Integer(value) }
	end

	assert_equal 7, klass.new.n
	assert_equal 7, Literal::Draft(klass).new.check.value!.n
end

test "a default goes through the prop's seal" do
	klass = Class.new(Literal::Data) do
		prop :name, _Frozen(String), default: -> { +"mutable" }, &Literal.Seal { |value| value.frozen? ? value : value.dup.freeze }
	end

	assert klass.new.name.frozen?
	assert Literal::Draft(klass).new.check.value!.name.frozen?
end

# A draft's slots carry values the prop's seal has not judged yet. When the
# seal raises after the input was already rejected, the raise is swallowed —
# and the slot must then read as unset, not as the value the seal refused,
# or a check would judge and splice a value the type pass never accepted.
test "a slot whose seal raised reads as unset, not as the input's value" do
	klass = Class.new(Literal::Data) do
		prop :a, Integer
		prop :b, String, &Literal.Seal { |value| raise "boom" if value == "boom"; value }

		check(:b, "must not be %{b}") { |b:| b != "boom" }
	end

	draft = Literal::Draft(klass).new(b: "boom")
	assert_equal [[:a, "is missing"]], errors_for(draft.check)
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
		draft_check: -> { Literal::Draft(klass).new(name: "a").check.value! },
		props_check: -> { Literal::Draft(klass).check(name: "a").value! },
		finalize: -> { Literal::Draft(klass).new(name: "a").finalize },
	}.each do |label, build|
		coercions = 0
		seals = 0
		build.call
		counts[label] = [coercions, seals]
	end

	assert_equal(
		{ new: [1, 1], draft_check: [1, 1], props_check: [1, 1], finalize: [1, 1] },
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
	assert draft.check.value!.name.frozen?
end

# --- writers enforce too ---

# A writer enforces the checks whose outcome depends on its property, so an
# object is valid always, not only at construction.
test "a writer enforces a check that reads its property, wherever the error is filed" do
	klass = Class.new(Literal::Struct) do
		prop :min, Integer
		prop :max, Integer
		check(:max, "must be greater than min") { |max:, min:| max > min }
	end
	span = klass.new(min: 1, max: 5)

	# Filed against :max, but writing :min changes the outcome, so :min's writer
	# enforces it too.
	assert_raises(Literal::CheckError) { span.min = 10 }
	assert_equal 1, span.min

	assert_raises(Literal::CheckError) { span.max = 0 }
	assert_equal 5, span.max

	span.max = 9

	assert_equal 9, span.max
end

# Where the error goes has no bearing on whether the outcome can change, so a
# writer for a property that is only ever reported against — never read — has
# nothing to enforce and no check emitted.
test "a property no check depends on gets no check in its writer" do
	klass = Class.new(Literal::Struct) do
		prop :n, Integer
		prop :note, String
		check(:n, "must be positive") { |n:| n > 0 }
	end
	object = klass.new(n: 1, note: "x")

	refute_includes klass.literal_properties[:note].generate_writer_method(+""), "__literal_run_checks__"

	object.note = "y"

	assert_equal "y", object.note
	assert_raises(Literal::CheckError) { object.n = -1 }
end

# Two interdependent properties cannot be moved one at a time — the intermediate
# state is exactly what the check forbids. That transition goes through a
# draft or `from_props`, which judge the whole value at once.
test "a transition that needs two properties at once goes through from_props" do
	klass = Class.new(Literal::Struct) do
		prop :min, Integer
		prop :max, Integer
		check(:max, "must be greater than min") { |max:, min:| max > min }
	end
	span = klass.new(min: 1, max: 5)

	assert_raises(Literal::CheckError) { span.min = 10 }

	moved = klass.from_props(span.to_h.merge(min: 10, max: 20))

	assert_equal [10, 20], [moved.min, moved.max]
end

# The checks judge the prospective value before it is stored, so a predicate
# that raises out of its own bug — not just one that fails — leaves the object
# untouched, holding a value its checks can still be evaluated against.
test "a raising predicate leaves the written property untouched" do
	klass = Class.new(Literal::Struct) do
		prop :min, _Nilable(Integer)
		prop :max, Integer
		check(:max, "must be greater than min") { |max:, min:| max > min }
	end
	span = klass.new(min: 1, max: 5)

	assert_raises(ArgumentError) { span.min = nil }

	assert_equal 1, span.min
	assert_equal 5, span.max
end

# An unchecked writer ends with the assignment and answers the value, so a
# checked one must too — `send(:"#{name}=", value)` chains read the result.
test "a checked writer returns the written value" do
	klass = Class.new(Literal::Struct) do
		prop :n, Integer
		check(:n, "must be positive") { |n:| n > 0 }
	end
	object = klass.new(n: 1)

	assert_equal 9, object.__send__(:n=, 9)
end

# --- what a check is handed ---

# An undefinable property that was not given holds Literal::Undefined, which is
# not a value to judge — so a check reading one does not apply, rather than
# meeting the sentinel where it expects an Integer.
test "a check reading an undefinable prop does not apply when it was not given" do
	klass = Class.new(Literal::Data) do
		prop :a, Integer
		prop? :b, Integer
		check(:b, "must be positive") { |b:| b > 0 }
	end

	assert_equal Literal::Undefined, klass.new(a: 1).b
	assert Literal::Draft(klass).new(a: 1).check.success?
	assert Literal::Draft(klass).check({ a: 1 }).success?
	assert_equal [[:b, "must be positive"]], errors_for(Literal::Draft(klass).check({ a: 1, b: -1 }))
end

# nil is a value, so a nilable property that was given nothing is still judged.
test "a check reading a nilable prop applies to the nil" do
	klass = Class.new(Literal::Data) do
		prop :n, _Nilable(Integer)
		check(:n, "must be given") { |n:| !n.nil? }
	end

	assert_equal [[:n, "must be given"]], errors_for(Literal::Draft(klass).check({}))
end

# The values are the caller's own objects, so a check can mutate one. It is
# handed them to read; mutating one reaches the built value.
test "a check is handed the caller's own values" do
	seen = nil
	klass = Class.new(Literal::Data) do
		prop :tags, _Array(String)
		check(:tags, "must not be empty") { |tags:| seen = tags; !tags.empty? }
	end
	tags = ["a"]

	klass.new(tags:)

	assert seen.equal?(tags)
end

# --- a nested shape is any shape that builds from props ---

test "a nested Literal::Struct is checked by its own checks" do
	inner = Class.new(Literal::Struct) do
		prop :n, Integer
		check(:n, "must be positive") { |n:| n > 0 }
	end
	outer = Class.new(Literal::Data) { prop :inner, inner }

	assert Literal::Draft(outer).check({ inner: { n: 1 } }).success?

	result = Literal::Draft(outer).check({ inner: { n: -1 } })

	assert_equal [[:inner, "must be positive"]], errors_for(result)
	assert_equal %i[inner n], result.error!.errors.fetch(0).path
end

# Naming itself is the only way a shape can be recursive, so a deferred type has
# to nest like a direct reference — otherwise no recursive shape can be checked
# from props at all, which is the input this exists for.
test "a nested shape reached through _Deferred is checked by its own checks" do
	assert Literal::Draft(Node).check({ n: 1, child: { n: 2, child: nil } }).success?

	result = Literal::Draft(Node).check({ n: 1, child: { n: -2, child: nil } })

	assert_equal [[:child, "must be positive"]], errors_for(result)
	assert_equal %i[child n], result.error!.errors.fetch(0).path
end

test "a deferred shape given a scalar reads as an object, not as not allowed" do
	assert_equal [[:child, "must be an object"]], errors_for(Literal::Draft(Node).check({ n: 1, child: 42 }))
end

# The wrappers checking sees through are exactly the ones a draft slot relaxes —
# _Frozen fixes representation and prop?'s union marks omittability, neither
# changes what the value must be — so `draft.check` agrees with
# `draft.finalize` and a nested Hash reaches the shape either way.
test "a nested shape reached through _Frozen is checked by its own checks" do
	outer = Class.new(Literal::Data) { prop :account, _Frozen(Account) }

	result = Literal::Draft(outer).check({ account: { name: " " } })

	assert_equal [[:account, "must not be blank"]], errors_for(result)
	assert_equal %i[account name], result.error!.errors.fetch(0).path
end

test "a nested shape in a prop? slot is checked by its own checks" do
	outer = Class.new(Literal::Data) do
		prop :id, String
		prop? :account, Account
	end

	assert_equal "x", Literal::Draft(outer).check({ id: "1", account: { name: "x" } }).value!.account.name
	assert_equal(
		[[:account, "must not be blank"]],
		errors_for(Literal::Draft(outer).check({ id: "1", account: { name: " " } }))
	)
end

# Which of two union members a Hash meant is not knowable, so it is not judged
# against an arbitrarily chosen one.
test "a Hash for a union of two shapes reads as a plain type failure" do
	other = Class.new(Literal::Data) { prop :name, String }
	outer = Class.new(Literal::Data) { prop :value, _Union(Account, other) }

	result = Literal::Draft(outer).check({ value: { name: "x" } })

	assert_equal [[:value, "is not allowed"]], errors_for(result)
end

# A subclass draft carries props and checks its declared slot's shape knows
# nothing about; checking it as the declared shape would drop them silently.
test "a nested subclass draft checks as its own class" do
	employee = Class.new(Account) do
		prop :dept, String
		check(:dept, "must not be blank") { |dept:| !dept.strip.empty? }
	end
	outer = Class.new(Literal::Data) { prop :account, Account }

	draft = Literal::Draft(outer).new
	draft[:account] = Literal::Draft(employee).new(name: "Ada", tier: nil, dept: " ")

	assert_equal [[:account, "must not be blank"]], errors_for(draft.check)

	draft[:account] = Literal::Draft(employee).new(name: "Ada", tier: nil, dept: "Ops")
	built = draft.check.value!.account

	assert employee === built
	assert_equal "Ops", built.dept
end

# A Hash the prop's type already admits is a value, not a nested shape — `new`
# would store it as it is, and the soft path must agree.
test "a Hash a union member admits stays a Hash" do
	klass = Class.new(Literal::Data) { prop :value, _Union(Account, Hash) }

	assert_equal({ anything: 1 }, klass.new(value: { anything: 1 }).value)
	assert_equal({ anything: 1 }, Literal::Draft(klass).check({ value: { anything: 1 } }).value!.value)
	assert_equal({ name: "x" }, Literal::Draft(klass).check({ value: { name: "x" } }).value!.value)
end

# One shape reachable twice — directly and through _Deferred — is still one
# shape, not an ambiguity.
test "a shape reachable through two union members nests once" do
	klass = Class.new(Literal::Data) do
		extend Literal::Types
		prop :node, _Union(Node, _Deferred { Node })
	end

	assert_equal 1, Literal::Draft(klass).check({ node: { n: 1, child: nil } }).value!.node.n
end

test "a draft in a _Frozen slot checks as it finalizes" do
	outer = Class.new(Literal::Data) { prop :account, _Frozen(Account) }
	draft = Literal::Draft(outer).new
	draft[:account] = Literal::Draft(Account).new(name: "Initech", tier: nil)

	assert draft.sound?
	assert_equal "Initech", draft.finalize.account.name
	assert_equal "Initech", draft.check.value!.account.name
end

# Nesting is bounded because a SystemStackError is not a StandardError, so an
# unbounded walk would escape the boundary `Draft.check` is supposed to be.
# Only a deferred type can cycle, so this is the case the cap exists for.
test "cyclic input reports rather than exhausting the stack" do
	props = { n: 1 }
	props[:child] = props

	result = Literal::Draft(Node).check(props)
	error = result.error!.errors.fetch(-1)

	assert result.failure?
	assert_equal "is nested too deeply", error.message
	assert_equal 65, error.path.size
end

# --- declaration guards on the message ---

test "a message that is not a String raises at declaration time" do
	[nil, :symbolic, -> (min) { "must exceed #{min}" }].each do |message|
		error = assert_raises(Literal::ArgumentError) do
			Class.new(Literal::Data) do
				prop :min, Integer
				check(:min, message) { |min:| min > 0 }
			end
		end

		assert(/message is a String/.match?(error.message))
	end
end

# A slot is filled with a value the predicate judged, so it can only name a
# property the check reads — and a typo raises where it was written
# rather than on the first value that fails.
test "a message slot naming a property the check does not read raises at declaration time" do
	error = assert_raises(Literal::ArgumentError) do
		Class.new(Literal::Data) do
			prop :min, Integer
			prop :max, Integer
			check(:min, "must be under %{max}") { |min:| min > 0 }
		end
	end

	assert(/does not read :max/.match?(error.message))
end

# --- Draft.check takes props ---

# It is the entry point for input from outside, and a Hash is what that input
# is. A draft is asked directly instead.
test "Draft.check takes only a Hash" do
	[nil, [], 42, Literal::Draft(Account).new, Account.new(name: "Initech")].each do |input|
		error = assert_raises(Literal::ArgumentError) { Literal::Draft(Account).check(input) }

		assert(/takes a Hash of properties/.match?(error.message))
	end
end

test "Draft.check names the draft and the class it was given" do
	error = assert_raises(Literal::ArgumentError) { Literal::Draft(Account).check(42) }

	assert(/^Literal::Draft\(.*Account\)\.check takes a Hash of properties, got Integer$/.match?(error.message))
end

# Checking from props builds the value at the end of it, so a shape that cannot
# be built from props cannot be checked from them either. A draft of one still
# checks the values it holds — there is just no Hash form of the same question.
test "a shape that cannot be built from props cannot be checked from them" do
	klass = Class.new(Literal::Object) do
		prop :name, String
		check(:name, "must be filled") { |name:| !name.empty? }

		def self.name = "Widget"
	end

	error = assert_raises(Literal::ArgumentError) { Literal::Draft(klass).check({ name: "Ada" }) }

	assert_equal "Widget cannot be checked, because it cannot be built from props", error.message
	assert_raises(Literal::CheckError) { klass.new(name: "") }
end

test "an enum cannot be checked from props either" do
	klass = Class.new(Literal::Enum(Integer)) do
		prop :code, Integer

		def self.name = "Grade"
	end

	error = assert_raises(Literal::ArgumentError) { Literal::Draft(klass).check({ code: 1 }) }

	assert(/cannot be checked, because it cannot be built from props/.match?(error.message))
end

# A draft answers for the type it drafts, so the validator never has to guess
# which shape a draft was meant for — and refuses one it was not.
test "the validator refuses a draft of another shape" do
	error = assert_raises(Literal::ArgumentError) do
		Literal::Checks::Checker.check(Account, Literal::Draft(Address).new)
	end

	assert(/^Expected a draft of .*Account, got a draft of .*Address$/.match?(error.message))
end

# --- checks are the invariant: construction enforces them ---

# Every path that hands out an object enforces the checks, so an object that
# exists satisfies them. That is what lets nested checking trust an instance.
test "every construction path raises for a value that breaks a check" do
	[
		-> { Account.new(name: " ") },
		-> { Account.from_props({ name: " " }) },
		-> { Account.from(Account.allocate.tap { |a| a.instance_variable_set(:@name, " ") }) },
		-> { Account.build { |draft| draft.name = " " } },
		-> { Literal::Draft(Account).new(name: " ").finalize },
		-> { Literal::SerializationContext.new.deserialize({ "name" => " " }, type: Account) },
	].each do |construct|
		assert_raises(Literal::CheckError) { construct.call }
	end
end

# The unchecked finalizer is the validator's alone: public, it would be a
# construction path that skips the checks.
test "a draft cannot be finalized unchecked from outside" do
	draft = Literal::Draft(Account).new(name: " ")

	assert_raises(NoMethodError) { draft.__finalize_unchecked__ }
end

test "restoring a dumped object enforces its checks too" do
	version, attributes, was_frozen, frozen_values = Account.new(name: "Initech").as_pack
	pack = [version, attributes.merge(name: " "), was_frozen, frozen_values]

	assert_raises(Literal::CheckError) { Account.allocate.marshal_load(pack) }
end

test "an enum member that breaks a check raises at its definition" do
	assert_raises(Literal::CheckError) do
		Class.new(Literal::Enum(Integer)) do
			prop :code, Integer
			check(:code, "must be positive") { |code:| code > 0 }

			def self.name = "Grade"
			const_set(:A, new(1, code: -1))
		end
	end
end

# Members are idiomatically defined above the checks in the class body. A
# member must satisfy its shape's checks like any other instance, so a check
# declared below one enforces it retroactively — at the declaration, not left
# latent for nested checking to trust.
test "check enforces existing enum members retroactively" do
	assert_raises(Literal::CheckError) do
		Class.new(Literal::Enum(Integer)) do
			prop :code, Integer

			def self.name = "Grade"
			const_set(:A, new(1, code: -1))

			check(:code, "must be positive") { |code:| code > 0 }
		end
	end
end

# Members are judged before the check installs, so a rescued failure leaves
# the shape without the check rather than a live check behind a member that
# breaks it — a check that fails must not half-happen.
test "a check refused by an enum member installs nothing" do
	klass = Class.new(Literal::Enum(Integer)) do
		prop :code, Integer

		def self.name = "Grade"
		const_set(:A, new(1, code: -1))

		begin
			check(:code, "must be positive") { |code:| code > 0 }
		rescue Literal::CheckError
			# The refusal is the point; what matters is what it left behind.
		end
	end

	assert_equal [], klass.literal_checks
end

test "check accepts existing enum members that satisfy it" do
	klass = Class.new(Literal::Enum(Integer)) do
		prop :code, Integer

		def self.name = "Grade"
		const_set(:A, new(1, code: 1))

		check(:code, "must be positive") { |code:| code > 0 }
	end

	assert_equal 1, klass::A.code
	assert_equal ["must be positive"], klass.literal_checks.map(&:message)
end

# A member's customization block runs after the initializer checked, so the
# checks are judged again on the state it left — and before the member
# registers, so a failure leaves nothing behind.
test "a member block that breaks a check raises and registers nothing" do
	error = assert_raises(Literal::CheckError) do
		Class.new(Literal::Enum(Integer)) do
			prop :code, Integer

			def self.name = "Grade"

			check(:code, "must be positive") { |code:| code > 0 }

			new(1, code: 1) do
				@code = -1
			end
		end
	end

	assert error.message.include?("must be positive")
end

test "a member block that keeps the checks registers the member" do
	klass = Class.new(Literal::Enum(Integer)) do
		prop :code, Integer

		def self.name = "Grade"

		check(:code, "must be positive") { |code:| code > 0 }

		const_set(:A, new(1, code: 1) do
			@code = 2
		end)
	end

	assert_equal 2, klass::A.code
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

# The failure reports from the check declaration, trimmed of literal's own
# frames like every other checking path.
test "a retroactive member failure reports from the caller's code" do
	error = assert_raises(Literal::CheckError) do
		Class.new(Literal::Enum(Integer)) do
			prop :code, Integer

			def self.name = "Grade"
			const_set(:A, new(1, code: -1))

			check(:code, "must be positive") { |code:| code > 0 }
		end
	end

	refute error.backtrace.first.include?("lib/literal")
end

test "the error carries every failure collected, not just the first" do
	klass = Class.new(Literal::Data) do
		prop :a, Integer
		prop :b, Integer

		check(:a, "first") { |a:| false }
		check(:b, "second") { |b:| false }
	end

	error = assert_raises(Literal::CheckError) { klass.new(a: 1, b: 2) }

	assert_equal ["first", "second"], error.errors.errors.map(&:message)
end

# The checks step is emitted into the generated initializer, so without trimming
# the backtrace would start inside the eval'd code rather than at the caller.
test "the error reports from the caller, not from the generated initializer" do
	error = assert_raises(Literal::CheckError) { Account.new(name: " ") }

	assert_includes error.backtrace.first, "checks.test.rb"
end

# It never carries the offending object: checks are the invariant, so a value
# that breaks them is not handed out by any route, the error included.
test "the error does not carry the invalid object" do
	error = assert_raises(Literal::CheckError) { Account.new(name: " ") }

	assert_equal Account, error.shape
	refute error.respond_to?(:subject)
end

# The initializer is re-emitted when the first check is declared, so declaration
# order within the class body does not matter.
test "a check declared after the props is still enforced" do
	klass = Class.new(Literal::Data) do
		prop :n, Integer
		check(:n, "must be positive") { |n:| n > 0 }
	end

	assert_raises(Literal::CheckError) { klass.new(n: -1) }
end

# A subclass that adds no prop has no generated extension of its own until it
# declares a check, and would otherwise inherit an initializer that never checks.
test "a subclass that adds only a check enforces it, and its parent does not" do
	parent = Class.new(Literal::Data) { prop :n, Integer }
	child = Class.new(parent) do
		check(:n, "must be positive") { |n:| n > 0 }
	end

	assert_raises(Literal::CheckError) { child.new(n: -1) }
	assert_equal(-1, parent.new(n: -1).n)
end

test "a shape with no checks emits nothing to run them" do
	klass = Class.new(Literal::Data) { prop :n, Integer }

	refute_includes klass.literal_properties.generate_initializer(+""), "__literal_run_checks__"
end

# A draft is the shape's checks held in abeyance — that is what it is for — so it
# must never enforce the drafted type's checks at its own construction.
test "a draft of a shape with checks is not checked when it is built" do
	draft = Literal::Draft(Account).new(name: " ")

	assert_equal " ", draft.name
	refute draft.sound?
	assert_equal [[:name, "must not be blank"]], errors_for(draft.check)
end

# the soft path must not raise, whatever a coercion does — and a nested value that
# broke its own checks has field errors worth keeping.
test "a coercion that builds an invalid nested value reports under its prop" do
	klass = Class.new(Literal::Data) do
		prop(:account, Account) { |value| (Hash === value) ? Account.new(name: value[:wire_name]) : value }
	end

	result = Literal::Draft(klass).check(account: { wire_name: " " })

	assert_equal [[:account, "must not be blank"]], errors_for(result)
	assert_equal %i[account name], result.error!.errors.fetch(0).path
end

# --- reflection ---

# A shape answers its checks in declaration order, and each one says what it
# reads, what it is filed against, and what it says.
test "a shape answers its checks and what each of them reads" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		check(:max, "must be greater than %{min}") { |max:, min:| max > min }
		checks { |errors, min:| errors.add("…") if min.negative? }
	end

	predicate, reporting = klass.literal_checks

	assert Literal::Checks::Check === predicate
	assert_equal :max, predicate.prop
	assert_equal "must be greater than %{min}", predicate.message
	assert_equal %i[max min], predicate.reads

	assert reporting.prop.nil?
	assert reporting.message.nil?
	assert_equal [:min], reporting.reads
end

# The property a failure is filed against is not read unless the check asks for
# it — anonymously, or by name like any other read.
test "a check reads the pinned property only when it asks for it" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		check(:max, "must not be negative") { |min:| !min.negative? }
		check(:max, "must be positive", &:positive?)
	end

	keyword, anonymous = klass.literal_checks

	assert_equal [:min], keyword.reads
	assert_equal [:max], anonymous.reads
	refute keyword.depends_on?(:max)
	assert_equal [anonymous], klass.literal_checks_for(:max)
end

# What a writer needs: the checks an assignment can change the outcome of,
# which is the ones that read the property — never the ones merely filed
# against it.
test "a shape answers the checks that depend on one property" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		prop :note, String

		check(:max, "must be greater than %{min}") { |max:, min:| max > min }
	end

	check = klass.literal_checks.fetch(0)

	assert_equal [check], klass.literal_checks_for(:min)
	assert_equal [check], klass.literal_checks_for(:max)
	assert_equal [], klass.literal_checks_for(:note)

	assert check.depends_on?(:min)
	refute check.depends_on?(:note)
	assert check.applies_to?(%i[min max])
	refute check.applies_to?(%i[max])
end

# --- projections ---

# A projection keeps the checks that still mean something: every property
# one touches has to survive the slice, since a check that reads a dropped
# property has nothing to read.
test "slice keeps the checks whose properties all survive" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		check(:min, "must not be negative") { |min:| !min.negative? }
		check(:max, "must be greater than min") { |max:, min:| max > min }
	end

	sliced = klass.slice(:min)

	assert_equal ["must not be negative"], sliced.literal_checks.map(&:message)
end

# The projection is a shape in its own right, so what it kept is its invariant
# too — not a record of what the origin used to check.
test "a projection enforces the checks it kept" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer

		check(:min, "must not be negative") { |min:| !min.negative? }
		check(:max, "must be greater than min") { |max:, min:| max > min }
	end

	sliced = klass.slice(:min)

	assert_raises(Literal::CheckError) { sliced.new(min: -1) }
	assert_equal 1, sliced.new(min: 1).min
	assert_equal [[:min, "must not be negative"]], errors_for(Literal::Draft(sliced).new(min: -1).check)
end

# A check that loses a property it touches goes with it.
test "slice drops the checks whose properties went" do
	klass = Class.new(Literal::Data) do
		prop :name, String
		prop :code, String

		check(:code, "must not be blank") { |code:| !code.empty? }
		check(:name, "must be filled") { |name:| !name.empty? }
	end

	sliced = klass.slice(:name)

	assert_equal ["must be filled"], sliced.literal_checks.map(&:message)
	assert_equal [[:name, "must be filled"]], errors_for(Literal::Draft(sliced).new(name: "").check)
end

# A projection's checks are set after its class body ran, so the writers it
# generated there knew nothing about them. Re-emitted, or the projection would
# enforce at construction and not on write — refusing an invalid object while
# letting one be mutated into the same state.
test "a projection's writers enforce the checks it kept" do
	klass = Class.new(Literal::Struct) do
		prop :min, Integer, writer: :public
		prop :max, Integer, writer: :public

		check(:max, "must be greater than min") { |max:, min:| max > min }
	end

	sliced = klass.slice(:min, :max)
	projection = sliced.new(min: 1, max: 5)

	assert_raises(Literal::CheckError) { projection.max = 0 }
	assert_equal 5, projection.max

	# The property read but not reported against is enforced the same way.
	assert_raises(Literal::CheckError) { projection.min = 10 }
	assert_equal 1, projection.min

	projection.max = 9

	assert_equal 9, projection.max
end

# When the slice drops a property, the base walk passes the origin, so during
# the projection's class body its checks resolve to an ancestor's — and the
# per-property tables memoized then are stale once the kept checks are set.
test "a projection that drops a property still enforces in its writers" do
	klass = Class.new(Literal::Struct) do
		prop :min, Integer, writer: :public
		prop :max, Integer, writer: :public
		prop :note, String

		check(:max, "must be greater than min") { |max:, min:| max > min }
	end

	sliced = klass.slice(:min, :max)
	projection = sliced.new(min: 1, max: 5)

	assert_raises(Literal::CheckError) { projection.min = 10 }
	assert_equal 1, projection.min
end

# A reporting check names its property only as it runs, so the slice cannot
# know to drop it; filing against a property the slice does not have is the
# check's own bug and raises against the slice, not the origin.
test "a reporting check kept by a slice files against what the slice has" do
	klass = Class.new(Literal::Data) do
		prop :min, Integer
		prop :max, Integer
		prop :note, String

		checks do |errors, min:, max:|
			errors.add(:note, "must explain the inversion") if min > max
		end
	end

	sliced = klass.slice(:min, :max)

	assert_equal 1, sliced.literal_checks.size
	assert_equal 5, sliced.new(min: 1, max: 5).max

	error = assert_raises(Literal::ArgumentError) { sliced.new(min: 5, max: 1) }

	assert(/has no :note property for a check to report against/.match?(error.message))
end

# A draft holds its type's checks in abeyance; one of its own would be
# enforced by the draft's initializer, which is the one place checks must
# not run.
test "a draft class refuses to declare checks" do
	error = assert_raises(Literal::ArgumentError) do
		Literal::Draft(Address).checks { |errors, city:| errors.add(:city, "no") }
	end

	assert_equal "Cannot declare checks on a draft; declare them on #{Address.name}.", error.message
end

test "the error message names the unsound shape" do
	error = assert_raises(Literal::CheckError) do
		Person.new(**valid_props(name: "", account: Account.new(name: "Initech")))
	end

	assert_equal "Unsound #{Person.name}\n  name must be between 1 and 10 characters\n", error.message
end

# --- always on ---

test "every shape checks, with nothing to include" do
	assert Address.respond_to?(:check)
	assert Address.respond_to?(:checks)
	assert_equal "London", Literal::Draft(Address).new(city: "London").check.value!.city
	assert_equal [[:city, "must be a string"]], errors_for(Literal::Draft(Address).check(city: 42))
end
