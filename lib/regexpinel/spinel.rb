begin
  require_relative "../../regexpinel_spinel"
rescue LoadError
  begin
    require "regexpinel_spinel"
  rescue LoadError
    module Regexpinel
      module Spinel
        def self.available?
          false
        end
      end
    end
  end
else
  require_relative "../compiler"

  module Regexpinel
    module Spinel
      def self.available?
        true
      end

      def self.new(pattern)
        Pattern.compile(pattern)
      end

      class Pattern
        def self.compile(pattern)
          new(Regexpinel.compile(pattern))
        end
      end

      Regexp = Pattern
    end
  end
end
