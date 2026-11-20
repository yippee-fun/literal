#!/usr/bin/env ruby
# frozen_string_literal: true

# Time to define a Literal::Struct and build its first instance.
#
#   bundle exec ruby -Ilib bench_definition.rb

require "literal"

CLASSES = 200

def realtime
	start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
	yield
	Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
end

def define_classes(size)
	CLASSES.times do
		Class.new(Literal::Struct) do
			size.times { |i| prop :"prop_#{i}", Integer, default: 0 }
		end.new
	end
end

[5, 20, 80].each do |size|
	time = 3.times.map {
		GC.start
		realtime { define_classes(size) }
	}.min

	puts format("%2d props: %7.1fms", size, time * 1000)
end
