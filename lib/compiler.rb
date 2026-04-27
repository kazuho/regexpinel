require_relative "compiler_core"
require_relative "regexpinel/closure_tables"

module Regexpinel
  def self.compile(pattern)
    nr_compile(pattern)
    $nr_code
  end

  def self.compile_closure_tables(code)
    nr_compile_closure_tables(code)
  end
end
