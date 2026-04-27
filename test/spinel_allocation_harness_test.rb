#!/usr/bin/env ruby

require "tmpdir"
require "open3"
require "rbconfig"
require_relative "../tools/spinel_support"

module SpinelAllocationHarnessTest
  module_function

  def run_cmd(*cmd)
    out, status = Open3.capture2e(*cmd)
    unless status.success?
      raise "command failed: #{cmd.join(' ')}\n#{out}"
    end
    out
  end

  def main
    Dir.mktmpdir("regexpinel-alloc-") do |dir|
      generated_c = File.join(dir, "proof_vm_argv.generated.c")
      raw_core_c = File.join(dir, "regexpinel_raw_core.c")
      harness_bin = File.join(dir, "allocation_harness")

      root = RegexpinelSpinelSupport.root
      run_cmd(RegexpinelSpinelSupport.ruby_env, RegexpinelSpinelSupport.spinel_exe, File.join(root, "bin/proof_vm_argv.rb"), "-c", "-o", generated_c)
      run_cmd(RbConfig.ruby, File.join(root, "tools/patch_raw_core.rb"), generated_c, raw_core_c)

      run_cmd(
        "cc",
        "-O2",
        "-Wno-all",
        "-DNR_GENERATED_C_PATH=\"#{raw_core_c}\"",
        File.join(root, "test/allocation_harness.c"),
        "-lm",
        "-o",
        harness_bin
      )

      out = run_cmd(harness_bin)
      expected = [
        "match,0,3,0",
        "match,1,4,0",
        "matched1,1",
        "matched2,0",
        "matched3,1",
        "malloc_calls,0",
        "calloc_calls,0",
        "realloc_calls,0",
        "total_alloc_calls,0"
      ]

      actual = out.lines.map(&:strip)
      if actual != expected
        raise "unexpected harness output:\n#{out}"
      end

      puts "ok"
    end
  end
end

SpinelAllocationHarnessTest.main
