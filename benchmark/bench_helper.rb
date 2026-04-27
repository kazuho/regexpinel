require "json"
require "fileutils"
require "rbconfig"
require_relative "../lib/regexpinel"

module RegexpinelBench
  RESULTS_DIR = File.expand_path("../benchmark/results", __dir__)

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
    unless File.exist?(bundle)
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
