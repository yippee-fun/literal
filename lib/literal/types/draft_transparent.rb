# frozen_string_literal: true

# @api private
#
# The wrappers a draft slot sees through: `_Nilable`, `_Frozen`, `_Deferred`
# and unions. This module is the set's one definition — a walk that must agree
# with drafting, like which slots checking treats as nested, matches against
# it and enumerates children with `literal_child_types`, rather than keeping
# its own copy of the set.
#
# An including type answers `__relax__`, rebuilding itself around its relaxed
# children — the block relaxes one child — so DraftStateType need not know how
# each wrapper is put back together.
module Literal::Types::DraftTransparent
	def __relax__
		raise NoMethodError.new("#{self.class} includes DraftTransparent but does not define __relax__")
	end
end
