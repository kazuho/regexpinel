#!/usr/bin/env ruby

require "tmpdir"
require "open3"
require_relative "../lib/compiler"
require_relative "../tools/spinel_support"

module SpinelRunnerTest
  CASES = [
    ["ab", "ab", 0],
    ["ab", "ac", 0],
    ["ab", "zab", 1],
    ["a|b", "a", 0],
    ["a|b", "b", 0],
    ["a|b", "c", 0],
    ["a*", "", 0],
    ["a*", "aaa", 0],
    ["a+b", "aaab", 0],
    ["a+b", "b", 0],
    ["ab?", "a", 0],
    ["ab?", "ab", 0],
    [".b", "ab", 0],
    [".b", "zz", 0],
    ["a(b|c)d", "acd", 0],
    ["a(b|c)d", "zacd", 1]
  ]

  module_function

  def capture_cmd(*cmd)
    out, status = Open3.capture2e(*cmd)
    unless status.success?
      raise "command failed: #{cmd.join(' ')}\n#{out}"
    end
    out
  end

  def compile_spinel_runner
    dir = Dir.mktmpdir("regexpinel-runner-")
    bin = File.join(dir, "run_vm_spinel")
    capture_cmd(RegexpinelSpinelSupport.ruby_env, RegexpinelSpinelSupport.spinel_exe, File.join(RegexpinelSpinelSupport.root, "bin/run_vm.rb"), "-o", bin)
    bin
  end

  def compile_pattern_csv(pattern)
    Regexpinel.compile(pattern).join(",")
  end

  def run_cruby_runner(code_csv, input, start_pos)
    capture_cmd("ruby", File.join(RegexpinelSpinelSupport.root, "bin/run_vm.rb"), code_csv, input, start_pos.to_s)
  end

  def run_spinel_runner(bin, code_csv, input, start_pos)
    capture_cmd(bin, code_csv, input, start_pos.to_s)
  end

  def main
    spinel_bin = compile_spinel_runner
    i = 0
    while i < CASES.length
      pattern = CASES[i][0]
      input = CASES[i][1]
      start_pos = CASES[i][2]
      code_csv = compile_pattern_csv(pattern)
      cruby_out = run_cruby_runner(code_csv, input, start_pos)
      spinel_out = run_spinel_runner(spinel_bin, code_csv, input, start_pos)
      if cruby_out != spinel_out
        raise "output mismatch for #{pattern.inspect} on #{input.inspect} at #{start_pos}\ncruby:\n#{cruby_out}\nspinel:\n#{spinel_out}"
      end
      i += 1
    end
    puts "ok"
  end
end

SpinelRunnerTest.main
