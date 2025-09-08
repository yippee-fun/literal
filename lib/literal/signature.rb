# frozen_string_literal: true

module Literal
	module Signature
		class Error < StandardError; end

		def Signature.extended(mod)
			mod.extend Types
		end

		def sig(**kwargs)
			@_sig = kwargs
		end

		def method_added(method_name)
			arg_sig = lambda do |parameters, signature|
				parameters
					.reject do |p_type, p_name| # rubocop:disable Style/HashExcept
					p_type == :block
				end
					.to_h do |p_type, p_name|
					sig_type = signature.key?(p_name) ? signature[p_name] : _Any

					p_sig = case p_type
												when :req, :keyreq then sig_type
												when :opt, :key then _Nilable(sig_type)
												when :rest then _Array(sig_type)
												when :keyrest then _Hash(_Symbol, sig_type)
												else
													nil
					end

					[p_name, p_sig]
				end
			end

			arg_destructor = lambda do |parameters|
				parameters.map do |p_type, p_name|
					case p_type
										when :req, :opt then p_name.to_s
										when :rest then "*#{p_name}"
										else
											nil
					end
				end.compact
			end

			kwarg_destructor = lambda do |parameters|
				parameters.map do |p_type, p_name|
					case p_type
										when :keyreq, :key then "#{p_name}:"
										when :keyrest then "**#{p_name}"
										else
											nil
					end
				end.compact
			end

			opt_kwarg_padding = lambda do |parameters|
				optional_keyword_params = parameters.select do |p_type, p_name|
					p_type == :key
				end.map(&:last)

				optional_keyword_params.to_h do |p_name|
					[p_name, nil]
				end
			end

			return unless @_sig
			signature = @_sig
			@_sig = nil

			old_method = instance_method(method_name)

			define_method(method_name) do |*args, **kwargs, &block|
				raise Error, "Signature defined for non-existent param!" unless signature.keys.to_set.subset? old_method.parameters.to_set(&:last)

				arg_binding = binding
				eval("#{arg_destructor.call(old_method.parameters).push('whatever').join(', ')} = *args, 0", arg_binding)
				eval("{ **opt_kwarg_padding.call(old_method.parameters), **kwargs } => {#{kwarg_destructor.call(old_method.parameters).join(', ')}}", arg_binding)

				signature.each do |param, type|
					value = begin
						arg_binding.local_variable_get(param.to_s)
					rescue NameError
						nil
					end
					arg_type = arg_sig.call(old_method.parameters, signature)[param.to_sym]

					raise Error, "#{value} doesn't match type #{arg_type}" unless arg_type === value
				end

				old_method.bind(self).(*args, **kwargs, &block)
			end
		end
	end
end
