#!/usr/bin/env ruby

loops = 500000
if ARGV.length > 0
  loops = ARGV[0].to_i
end

puts "mode,cruby_regexp_subset"
puts "loops,#{loops}"

re = /ab/
started = Time.now.to_f
matches = 0
i = 0
while i < loops
  if "ab".match?(re)
    matches += 1
  end
  i += 1
end
elapsed = Time.now.to_f - started
puts "case,literal-ab-match,1,#{loops},#{elapsed},#{loops / elapsed},#{matches}"

re = /ab/
started = Time.now.to_f
matches = 0
i = 0
while i < loops
  if "ac".match?(re)
    matches += 1
  end
  i += 1
end
elapsed = Time.now.to_f - started
puts "case,literal-ab-miss,1,#{loops},#{elapsed},#{loops / elapsed},#{matches}"

re = /a|b/
started = Time.now.to_f
matches = 0
i = 0
while i < loops
  if "b".match?(re)
    matches += 1
  end
  i += 1
end
elapsed = Time.now.to_f - started
puts "case,alternation-a-or-b-match,1,#{loops},#{elapsed},#{loops / elapsed},#{matches}"

re = /a*/
started = Time.now.to_f
matches = 0
i = 0
while i < loops
  if "aaaa".match?(re)
    matches += 1
  end
  i += 1
end
elapsed = Time.now.to_f - started
puts "case,kleene-a-star-match,1,#{loops},#{elapsed},#{loops / elapsed},#{matches}"

re = /a(b|c)d/
started = Time.now.to_f
matches = 0
i = 0
while i < loops
  if "acd".match?(re)
    matches += 1
  end
  i += 1
end
elapsed = Time.now.to_f - started
puts "case,group-alt-match,1,#{loops},#{elapsed},#{loops / elapsed},#{matches}"
