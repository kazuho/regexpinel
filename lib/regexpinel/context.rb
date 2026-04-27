module Regexpinel
  class Context
    attr_reader :current_states, :next_states, :mark_tokens, :epsilon_stack
    attr_accessor :current_count, :next_count, :mark_token, :matched

    def initialize(state_capacity, instruction_count)
      @current_states = Array.new(state_capacity, 0)
      @next_states = Array.new(state_capacity, 0)
      @mark_tokens = Array.new(instruction_count, 0)
      @epsilon_stack = Array.new(instruction_count, 0)
      @current_count = 0
      @next_count = 0
      @mark_token = 1
      @matched = false
    end

    def begin_run
      @current_count = 0
      @next_count = 0
      @matched = false
      advance_mark_token
    end

    def advance_mark_token
      @mark_token += 1
      if @mark_token == 0
        i = 0
        while i < @mark_tokens.length
          @mark_tokens[i] = 0
          i += 1
        end
        @mark_token = 1
      end
    end

    def swap_sets
      tmp_states = @current_states
      @current_states = @next_states
      @next_states = tmp_states
      @current_count = @next_count
      @next_count = 0
    end
  end
end
