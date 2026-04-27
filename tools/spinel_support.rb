require "rbconfig"

module RegexpinelSpinelSupport
  module_function

  def root
    File.expand_path("..", __dir__)
  end

  def spinel_exe
    spinel = ENV["SPINEL"]
    return spinel if spinel && !spinel.empty?

    abort "SPINEL must point to the external Spinel command"
  end

  def ruby_env
    ruby_bindir = File.dirname(RbConfig.ruby)
    { "PATH" => "#{ruby_bindir}:#{ENV["PATH"]}" }
  end
end
