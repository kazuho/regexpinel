require_relative "compiler_core"

module Regexpinel
  def self.compile(pattern)
    nr_compile(pattern)
    $nr_code
  end
end
