#!/usr/bin/env ruby

require "open3"
require "rbconfig"
require "tmpdir"
require_relative "../tools/spinel_support"

module AllocationProofCheck
  ALLOC_SYMBOLS = %w[
    _malloc
    _calloc
    _realloc
    _free
    _mmap
    _mmap64
    _munmap
    _posix_memalign
    _aligned_alloc
    _valloc
    _vm_allocate
  ].freeze

  ALLOWED_SETUP_MALLOC_MAIN_OFFSETS = [].freeze
  REQUIRED_GENERATED_SYMBOLS = %w[
    sp_nr_core_add_state
    sp_nr_core_match
    nr_match_core
  ].freeze
  FORBIDDEN_GENERATED_SYMBOLS = %w[
    sp_nr_proof
    sp_nr_poc_add_state
    sp_nr_poc_match
    sp_gc_alloc
    sp_gc_alloc_nogc
    sp_IntArray
    sp_Fiber
    sp_lam_alloc
    malloc
    calloc
    realloc
    free
    mmap
    fputs
    printf
    puts
    putchar
    strlen
  ].freeze
  FORBIDDEN_LINKED_SYMBOL_PATTERNS = [
    /\b_sp_gc_alloc(?:_nogc)?\b/,
    /\b_sp_IntArray/,
    /\b_sp_FloatArray/,
    /\b_sp_PtrArray/,
    /\b_sp_StrArray/,
    /\b_sp_StrIntHash/,
    /\b_sp_StrStrHash/,
    /\b_sp_String(?:IO|_new)?\b/,
    /\b_sp_Fiber/,
    /\b_sp_lam_alloc\b/
  ].freeze

  module_function

  def run_cmd(*cmd)
    out, status = Open3.capture2e(*cmd)
    unless status.success?
      raise "command failed: #{cmd.join(' ')}\n#{out}"
    end
    out
  end

  def parse_imported_symbols(nm_output)
    nm_output.lines.map(&:strip).select { |line| line.start_with?("_") }
  end

  def parse_stub_symbols(otool_iv)
    stubs = {}
    in_stubs = false
    otool_iv.each_line do |line|
      if line.include?("Indirect symbols for (__TEXT,__stubs)")
        in_stubs = true
        next
      end
      if in_stubs && line.start_with?("Indirect symbols for ")
        break
      end
      next unless in_stubs

      if line =~ /\A0x([0-9a-fA-F]+)\s+\d+\s+(_\S+)/
        stubs[$1.to_i(16)] = $2
      end
    end
    stubs
  end

  def parse_disassembly_calls(disasm, stubs)
    calls = []
    current_function = nil
    current_function_addr = nil

    disasm.each_line do |line|
      if line =~ /\A_([A-Za-z0-9_]+):/
        current_function = "_#{$1}"
        current_function_addr = nil
        next
      end

      if current_function_addr.nil? && line =~ /\A([0-9a-fA-F]+)\s+/
        current_function_addr = $1.to_i(16)
      end

      next unless line =~ /\A([0-9a-fA-F]+)\s+bl\s+0x([0-9a-fA-F]+)/

      call_addr = $1.to_i(16)
      target_addr = $2.to_i(16)
      symbol = stubs[target_addr]
      next unless symbol && ALLOC_SYMBOLS.include?(symbol)

      calls << {
        function: current_function,
        function_addr: current_function_addr,
        call_addr: call_addr,
        offset: current_function_addr ? call_addr - current_function_addr : nil,
        symbol: symbol,
        line: line.strip
      }
    end
    calls
  end

  def setup_malloc_call?(call)
    call[:function] == "_main" &&
      call[:symbol] == "_malloc" &&
      ALLOWED_SETUP_MALLOC_MAIN_OFFSETS.include?(call[:offset])
  end

  def validate_generated_source(generated_c)
    source = File.read(generated_c)
    missing = REQUIRED_GENERATED_SYMBOLS.reject { |symbol| source.include?(symbol) }
    forbidden = FORBIDDEN_GENERATED_SYMBOLS.select { |symbol| source.include?(symbol) }

    unless missing.empty?
      raise "generated C does not contain shared core symbols: #{missing.join(", ")}"
    end
    unless forbidden.empty?
      raise "generated C contains forbidden non-core/runtime symbols: #{forbidden.join(", ")}"
    end
  end

  def linked_runtime_alloc_symbols(nm_output)
    nm_output.lines.select do |line|
      ALLOC_SYMBOLS.any? { |symbol| line.include?(symbol) && !line.include?("(undefined) external _malloc") } ||
        FORBIDDEN_LINKED_SYMBOL_PATTERNS.any? { |pattern| line.match?(pattern) }
    end
  end

  def main
    Dir.mktmpdir("regexpinel-binary-alloc-") do |dir|
      generated_c = File.join(dir, "proof_vm_argv.generated.c")
      raw_core_c = File.join(dir, "regexpinel_raw_core.c")
      binary = File.join(dir, "proof_vm_argv")

      root = RegexpinelSpinelSupport.root
      run_cmd(RegexpinelSpinelSupport.ruby_env, RegexpinelSpinelSupport.spinel_exe, File.join(root, "bin/proof_vm_argv.rb"), "-c", "-o", generated_c)
      run_cmd(RbConfig.ruby, File.join(root, "tools/patch_raw_core.rb"), generated_c, raw_core_c)
      validate_generated_source(raw_core_c)
      run_cmd(
        "cc",
        "-O2",
        "-Wno-all",
        "-I#{dir}",
        File.join(root, "tools/proof_vm_argv_raw.c"),
        "-lm",
        "-Wl,-dead_strip",
        "-o",
        binary
      )

      imported = parse_imported_symbols(run_cmd("nm", "-u", binary))
      imported_allocators = imported & ALLOC_SYMBOLS
      if imported.include?("_mmap") || imported.include?("_mmap64")
        raise "binary imports mmap:\n#{imported_allocators.join("\n")}"
      end
      linked_allocators = linked_runtime_alloc_symbols(run_cmd("nm", "-m", binary))
      unless linked_allocators.empty?
        raise "binary links Spinel allocator/runtime allocation symbols:\n#{linked_allocators.join}"
      end

      otool_iv = run_cmd("otool", "-Iv", binary)
      stubs = parse_stub_symbols(otool_iv)
      calls = parse_disassembly_calls(run_cmd("otool", "-tvV", binary), stubs)
      violations = calls.reject { |call| setup_malloc_call?(call) }

      puts "binary,#{binary}"
      puts "shared_core_symbols,#{REQUIRED_GENERATED_SYMBOLS.join(":")}"
      puts "imported_allocators,#{imported_allocators.join(":")}"
      puts "allocator_call_count,#{calls.length}"
      calls.each do |call|
        offset = call[:offset] ? "0x#{call[:offset].to_s(16)}" : "unknown"
        puts "allocator_call,#{call[:symbol]},#{call[:function]},#{offset},0x#{call[:call_addr].to_s(16)}"
      end

      unless violations.empty?
        puts "violations,#{violations.length}"
        violations.each do |call|
          offset = call[:offset] ? "0x#{call[:offset].to_s(16)}" : "unknown"
          puts "violation,#{call[:symbol]},#{call[:function]},#{offset},0x#{call[:call_addr].to_s(16)}"
        end
        exit 1
      end

      puts "ok"
    end
  end
end

AllocationProofCheck.main
