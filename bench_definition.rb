#!/usr/bin/env ruby
# frozen_string_literal: true

# Time to define a Literal::Struct, one prop at a time and as one batch.
#
#   bundle exec ruby -Ilib bench_definition.rb

require "literal"

CLASSES = 200

def realtime
	start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
	yield
	Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
end

def define_classes(size, batched:)
	CLASSES.times do
		Class.new(Literal::Struct) do
			declare = -> { size.times { |i| prop :"prop_#{i}", Integer } }
			batched ? props(&declare) : declare.call
		end
	end
end

[5, 20, 80].each do |size|
	unbatched, batched = [false, true].map do |batched|
		3.times.map {
			GC.start
			realtime { define_classes(size, batched:) }
		}.min
	end

	puts format(
		"%2d props: %7.1fms unbatched, %6.1fms batched, %.1fx",
		size,
		unbatched * 1000,
		batched * 1000,
		unbatched / batched,
	)
end
