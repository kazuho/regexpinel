require_relative "context"

module Regexpinel
  module Executor
    OP_CHAR = 1
    OP_ANY = 2
    OP_JMP = 3
    OP_SPLIT = 4
    OP_MATCH = 5

    module_function

    def match?(code, string, start_pos, ctx)
      ctx.begin_run
      add_current_state(code, 0, ctx)
      return true if ctx.matched

      pos = start_pos
      while pos < string.length
        byte = string.getbyte(pos)
        step(code, byte, ctx)
        return true if ctx.matched
        return false if ctx.current_count == 0
        pos += 1
      end

      false
    end

    def step(code, byte, ctx)
      ctx.advance_mark_token
      i = 0
      while i < ctx.current_count
        pc = ctx.current_states[i]
        base = pc * 3
        op = code[base]
        if op == OP_CHAR
          if byte == code[base + 1]
            add_next_state(code, code[base + 2], ctx)
          end
        elsif op == OP_ANY
          add_next_state(code, code[base + 1], ctx)
        end
        i += 1
      end
      ctx.swap_sets
    end

    def add_current_state(code, pc, ctx)
      add_state(code, pc, ctx.current_states, 0, ctx)
    end

    def add_next_state(code, pc, ctx)
      add_state(code, pc, ctx.next_states, 1, ctx)
    end

    def add_state(code, pc, target_states, target_kind, ctx)
      stack = ctx.epsilon_stack
      stack_top = 0
      stack[stack_top] = pc
      stack_top += 1

      while stack_top > 0
        stack_top -= 1
        cur = stack[stack_top]
        next if ctx.mark_tokens[cur] == ctx.mark_token
        ctx.mark_tokens[cur] = ctx.mark_token

        base = cur * 3
        op = code[base]

        if op == OP_JMP
          stack[stack_top] = code[base + 1]
          stack_top += 1
        elsif op == OP_SPLIT
          stack[stack_top] = code[base + 1]
          stack_top += 1
          stack[stack_top] = code[base + 2]
          stack_top += 1
        elsif op == OP_MATCH
          ctx.matched = true
        else
          if target_kind == 0
            count = ctx.current_count
            target_states[count] = cur
            ctx.current_count = count + 1
          else
            count = ctx.next_count
            target_states[count] = cur
            ctx.next_count = count + 1
          end
        end
      end
    end
  end
end
