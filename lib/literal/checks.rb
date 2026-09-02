# frozen_string_literal: true

# Namespace for the checking machinery. The API lives on Literal::Properties,
# so every shape has it — there is nothing to include.
#
#   class Span < Literal::Data
#     prop :min, Integer
#     prop :max, Integer
#
#     check(:min, "must not be negative") { !it.negative? }
#
#     checks do |errors, min:, max:|
#       errors.add(:max, "must be greater than min (#{min})") unless max > min
#     end
#   end
#
# A check's block is handed values, never the object; its keyword parameters
# name the properties it reads. Checks run once the types hold and do not
# depend on one another. Every construction path enforces them, raising
# Literal::CheckError; `Draft#check` and `Draft.check` collect instead,
# building only once everything holds.
module Literal::Checks
end
