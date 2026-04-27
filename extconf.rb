require "mkmf"
require "fileutils"
require_relative "tools/spinel_support"

root = RegexpinelSpinelSupport.root
source_dir = File.expand_path("src", __dir__)
generated_dir = File.join(source_dir, "generated")
generated_c = File.join(generated_dir, "regexpinel_spinel_core.c")
raw_generated_c = File.join(generated_dir, "regexpinel_spinel_core.raw.c")

FileUtils.mkdir_p(generated_dir)
unless system(RegexpinelSpinelSupport.ruby_env, RegexpinelSpinelSupport.spinel_exe, File.join(root, "bin/proof_vm_argv.rb"), "-c", "-o", raw_generated_c, out: File::NULL, err: File::NULL)
  abort "failed to generate Spinel native regexp core"
end
unless system(RbConfig.ruby, File.join(root, "tools/patch_raw_core.rb"), raw_generated_c, generated_c, out: File::NULL)
  abort "failed to patch Spinel native regexp core"
end

$VPATH << "$(srcdir)/src"
$INCFLAGS << " -I$(srcdir)/src"
$srcs = ["regexpinel_spinel.c"]

create_makefile("regexpinel_spinel")
