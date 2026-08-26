# frozen_string_literal: true

# Namespace for the validation machinery. The API lives on
# Literal::Properties, so every shape has it — there is nothing to include.
#
#   class Span < Literal::Data
#     prop :min, Integer
#     prop :max, Integer
#
#     stipulate(:min, "must not be negative") { |min| !min.negative? }
#     stipulate(:max, "must be greater than %{min}") { |min, max| max > min }
#   end
#
# A stipulation's predicate is handed values, never the object; its parameter
# names name the properties it reads. A failure is filed against the given
# property (or the value as a whole when none is given) and taints it; a
# stipulation reading a tainted property is skipped. Every construction path
# enforces the rules, raising Literal::ValidationError; `validate` and
# `validate_from_props` collect instead, building only once everything holds.
module Literal::Validations
end
