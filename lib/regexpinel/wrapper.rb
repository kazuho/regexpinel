require_relative "bytecode_wrapper"

def nr_run_with_context(code, string, start_pos, context)
  context[0] = code.length / 3
  nr_match(code, string, start_pos, context, context, context, context, context)
end

def nr_parse_code_csv(code_csv)
  parts = code_csv.split(",")
  code = []
  i = 0
  while i < parts.length
    code << parts[i].to_i
    i += 1
  end
  code
end

def nr_run_vm_code(code, string, start_pos)
  context = nr_make_context(code.length / 3)
  nr_match(code, string, start_pos, context, context, context, context, context)
end
