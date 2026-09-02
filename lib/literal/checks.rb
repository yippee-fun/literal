# frozen_string_literal: true

# Namespace for the checking machinery. The API lives on Literal::Properties,
# so every shape has it — there is nothing to include.
#
#   class Span < Literal::Data
#     prop :min, Integer
#     prop :max, Integer
#
#     checks do |errors, min:, max:|
#       errors.add(:max, "must be greater than min (#{min})") unless max > min
#     end
#
#     check(:min, "must not be negative") { !it.negative? }
#   end
#
# `checks` is the API: a block handed values, never the object, whose keyword
# parameters name the properties it reads, filing what it finds through the
# reporter. `check` is its short form for the common one-predicate, one-message
# case. Checks run once the types hold and do not depend on one another; a
# subclass adds to its parent's. Every construction path enforces them,
# raising Literal::CheckError; `Draft#check` and `Draft.check` collect
# instead, building only once everything holds.
module Literal::Checks
end
