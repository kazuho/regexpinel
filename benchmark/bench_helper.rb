require "json"
require "fileutils"
require "rbconfig"
require_relative "../lib/regexpinel"

module RegexpinelBench
  RESULTS_DIR = File.expand_path("../benchmark/results", __dir__)

  class CRubySubstitutionPattern
    def initialize(pattern)
      @regexp = Regexp.new(pattern)
    end

    def sub(string, replacement)
      string.sub(@regexp, replacement)
    end

    def gsub(string, replacement)
      string.gsub(@regexp, replacement)
    end
  end

  module_function

  def now_seconds
    Time.now.to_f
  end

  def bench_compile(pattern, loops)
    started = now_seconds
    i = 0
    while i < loops
      Regexpinel::CRuby.new(pattern)
      i += 1
    end
    now_seconds - started
  end

  def bench_regexpinel_match(pattern, inputs, loops)
    compiled = Regexpinel::CRuby.new(pattern)
    started = now_seconds
    total = 0
    loop_i = 0
    while loop_i < loops
      i = 0
      while i < inputs.length
        if compiled.match?(inputs[i])
          total += 1
        end
        i += 1
      end
      loop_i += 1
    end
    [now_seconds - started, total]
  end

  def ensure_spinel_extension
    return if defined?(Regexpinel::Spinel) && Regexpinel::Spinel.respond_to?(:available?) && Regexpinel::Spinel.available?

    root = File.expand_path("..", __dir__)
    bundle = File.join(root, "regexpinel_spinel.bundle")
    wrapper_source = File.join(root, "src/regexpinel_spinel.c")
    unless File.exist?(bundle) && File.mtime(bundle) >= File.mtime(wrapper_source)
      ruby = RbConfig.ruby
      unless system(ruby, "extconf.rb", chdir: root, out: File::NULL, err: File::NULL)
        raise "failed to configure Spinel extension"
      end
      unless system("make", chdir: root, out: File::NULL, err: File::NULL)
        raise "failed to build Spinel extension"
      end
    end

    require_relative "../lib/regexpinel/spinel"
    raise "spinel extension is unavailable" unless Regexpinel::Spinel.available?
  end

  def bench_spinel_match(pattern, inputs, loops)
    ensure_spinel_extension
    compiled = Regexpinel::Spinel.new(pattern)
    started = now_seconds
    total = 0
    loop_i = 0
    while loop_i < loops
      i = 0
      while i < inputs.length
        if compiled.match?(inputs[i])
          total += 1
        end
        i += 1
      end
      loop_i += 1
    end
    [now_seconds - started, total]
  end

  def bench_cruby_match(pattern, inputs, loops)
    re = Regexp.new(pattern)
    started = now_seconds
    total = 0
    loop_i = 0
    while loop_i < loops
      i = 0
      while i < inputs.length
        if re.match?(inputs[i])
          total += 1
        end
        i += 1
      end
      loop_i += 1
    end
    [now_seconds - started, total]
  end

  def bench_sub(compiled, inputs, replacement, loops)
    started = now_seconds
    total = 0
    loop_i = 0
    while loop_i < loops
      i = 0
      while i < inputs.length
        total += compiled.sub(inputs[i], replacement).bytesize
        i += 1
      end
      loop_i += 1
    end
    [now_seconds - started, total]
  end

  def bench_regexpinel_sub(pattern, inputs, replacement, loops)
    bench_sub(Regexpinel::CRuby.new(pattern), inputs, replacement, loops)
  end

  def bench_spinel_sub(pattern, inputs, replacement, loops)
    ensure_spinel_extension
    bench_sub(Regexpinel::Spinel.new(pattern), inputs, replacement, loops)
  end

  def bench_cruby_sub(pattern, inputs, replacement, loops)
    bench_sub(CRubySubstitutionPattern.new(pattern), inputs, replacement, loops)
  end

  def bench_gsub(compiled, inputs, replacement, loops)
    started = now_seconds
    total = 0
    loop_i = 0
    while loop_i < loops
      i = 0
      while i < inputs.length
        total += compiled.gsub(inputs[i], replacement).bytesize
        i += 1
      end
      loop_i += 1
    end
    [now_seconds - started, total]
  end

  def bench_regexpinel_gsub(pattern, inputs, replacement, loops)
    bench_gsub(Regexpinel::CRuby.new(pattern), inputs, replacement, loops)
  end

  def bench_spinel_gsub(pattern, inputs, replacement, loops)
    ensure_spinel_extension
    bench_gsub(Regexpinel::Spinel.new(pattern), inputs, replacement, loops)
  end

  def bench_cruby_gsub(pattern, inputs, replacement, loops)
    bench_gsub(CRubySubstitutionPattern.new(pattern), inputs, replacement, loops)
  end

  def checks_per_sec(input_count, loops, elapsed)
    return 0.0 if elapsed <= 0.0
    (input_count * loops) / elapsed
  end

  def write_results(name, rows)
    FileUtils.mkdir_p(RESULTS_DIR)
    path = File.join(RESULTS_DIR, "#{name}.json")
    File.write(path, JSON.pretty_generate(rows))
    path
  end
end
