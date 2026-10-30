# Diagnostic only, never loaded by a measured run: ruby -r/app/diag/alloc.rb /app/<b>.rb <n>
# prints the number of heap objects the whole run allocated, to stderr.
at_exit { $stderr.puts "allocated_objects=#{GC.stat(:total_allocated_objects)}" }
