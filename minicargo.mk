
RUSTC_CHANNEL ?= stable
RUSTC_VERSION ?= 1.19.0
OVERRIDE_SUFFIX ?= -linux
OUTDIR := output/

MRUSTC := bin/mrustc
MINICARGO := tools/bin/minicargo
ifeq ($(RUSTC_CHANNEL),nightly)
	RUSTCSRC := rustc-nightly-src/
else
	RUSTCSRC := rustc-$(RUSTC_VERSION)-src/
endif

LLVM_CONFIG := $(RUSTCSRC)build/bin/llvm-config
RUSTC_TARGET ?= x86_64-unknown-linux-gnu
#RUSTC_TARGET ?= x86_64-unknown-dragonfly
OVERRIDE_DIR := script-overrides/$(RUSTC_CHANNEL)-$(RUSTC_VERSION)$(OVERRIDE_SUFFIX)/

.PHONY: bin/mrustc tools/bin/minicargo
.PHONY: $(OUTDIR)libstd.hir $(OUTDIR)libtest.hir $(OUTDIR)libpanic_unwind.hir $(OUTDIR)libproc_macro.hir
.PHONY: $(OUTDIR)rustc $(OUTDIR)cargo

.PHONY: all LIBS


all: $(OUTDIR)rustc

LIBS: $(OUTDIR)libstd.hir $(OUTDIR)libtest.hir $(OUTDIR)libpanic_unwind.hir $(OUTDIR)libproc_macro.hir

$(MRUSTC):
	$(MAKE) -f Makefile all
	test -e $@

$(MINICARGO):
	$(MAKE) -C tools/minicargo/
	test -e $@

# Standard library crates
# - libstd, libpanic_unwind, libtest and libgetopts
# - libproc_macro (mrustc)
$(OUTDIR)libstd.hir: $(MRUSTC) $(MINICARGO)
	$(MINICARGO) $(RUSTCSRC)src/libstd --script-overrides $(OVERRIDE_DIR) --output-dir $(OUTDIR)
	test -e $@
$(OUTDIR)libpanic_unwind.hir: $(MRUSTC) $(MINICARGO) $(OUTDIR)libstd.hir
	$(MINICARGO) $(RUSTCSRC)src/libpanic_unwind --script-overrides $(OVERRIDE_DIR) --output-dir $(OUTDIR)
	test -e $@
$(OUTDIR)libtest.hir: $(MRUSTC) $(MINICARGO) $(OUTDIR)libstd.hir $(OUTDIR)libpanic_unwind.hir
	$(MINICARGO) $(RUSTCSRC)src/libtest --vendor-dir $(RUSTCSRC)src/vendor --output-dir $(OUTDIR)
	test -e $@
$(OUTDIR)libgetopts.hir: $(MRUSTC) $(MINICARGO) $(OUTDIR)libstd.hir
	$(MINICARGO) $(RUSTCSRC)src/libgetopts --script-overrides $(OVERRIDE_DIR) --output-dir $(OUTDIR)
	test -e $@
# MRustC custom version of libproc_macro
$(OUTDIR)libproc_macro.hir: $(MRUSTC) $(MINICARGO) $(OUTDIR)libstd.hir
	$(MINICARGO) lib/libproc_macro --output-dir $(OUTDIR)
	test -e $@

RUSTC_ENV_VARS := CFG_COMPILER_HOST_TRIPLE=$(RUSTC_TARGET)
RUSTC_ENV_VARS += LLVM_CONFIG=$(abspath $(LLVM_CONFIG))
RUSTC_ENV_VARS += CFG_RELEASE=
RUSTC_ENV_VARS += CFG_RELEASE_CHANNEL=$(RUSTC_CHANNEL)
RUSTC_ENV_VARS += CFG_VERSION=$(RUSTC_VERSION)-$(RUSTC_CHANNEL)-mrustc
RUSTC_ENV_VARS += CFG_PREFIX=mrustc
RUSTC_ENV_VARS += CFG_LIBDIR_RELATIVE=lib

$(OUTDIR)rustc: $(MRUSTC) $(MINICARGO) LIBS $(LLVM_CONFIG)
	mkdir -p $(OUTDIR)rustc-build
	$(RUSTC_ENV_VARS) $(MINICARGO) $(RUSTCSRC)src/rustc --vendor-dir $(RUSTCSRC)src/vendor --output-dir $(OUTDIR)rustc-build -L $(OUTDIR)
	cp $(OUTDIR)rustc-build/rustc $(OUTDIR)
$(OUTDIR)cargo: $(MRUSTC) LIBS
	mkdir -p $(OUTDIR)cargo-build
	$(MINICARGO) $(RUSTCSRC)src/tools/cargo --vendor-dir $(RUSTCSRC)src/vendor --output-dir $(OUTDIR)cargo-build -L $(OUTDIR)
	cp $(OUTDIR)cargo-build/cargo $(OUTDIR)

# Reference $(RUSTCSRC)src/bootstrap/native.rs for these values
LLVM_CMAKE_OPTS := LLVM_TARGET_ARCH=$(firstword $(subst -, ,$(RUSTC_TARGET))) LLVM_DEFAULT_TARGET_TRIPLE=$(RUSTC_TARGET)
LLVM_CMAKE_OPTS += LLVM_TARGETS_TO_BUILD=X86#;ARM;AArch64;Mips;PowerPC;SystemZ;JSBackend;MSP430;Sparc;NVPTX
LLVM_CMAKE_OPTS += LLVM_ENABLE_ASSERTIONS=OFF
LLVM_CMAKE_OPTS += LLVM_INCLUDE_EXAMPLES=OFF LLVM_INCLUDE_TESTS=OFF LLVM_INCLUDE_DOCS=OFF
LLVM_CMAKE_OPTS += LLVM_ENABLE_ZLIB=OFF LLVM_ENABLE_TERMINFO=OFF LLVM_ENABLE_LIBEDIT=OFF WITH_POLLY=OFF
LLVM_CMAKE_OPTS += CMAKE_CXX_COMPILER="g++" CMAKE_C_COMPILER="gcc"
LLVM_CMAKE_OPTS += CMAKE_BUILD_TYPE=RelWithDebInfo


$(LLVM_CONFIG): $(RUSTCSRC)build/Makefile
	$Vcd $(RUSTCSRC)build && $(MAKE)
$(RUSTCSRC)build/Makefile: $(RUSTCSRC)src/llvm/CMakeLists.txt
	@mkdir -p $(RUSTCSRC)build
	$Vcd $(RUSTCSRC)build && cmake $(addprefix -D , $(LLVM_CMAKE_OPTS)) ../src/llvm


#
# Developement-only targets
#
$(OUTDIR)rustc-build/librustdoc.hir: $(MRUSTC) LIBS
	$(MINICARGO) $(RUSTCSRC)src/librustdoc --vendor-dir $(RUSTCSRC)src/vendor --output-dir $(dir $@) -L $(OUTDIR)
#$(OUTDIR)cargo-build/libserde-1_0_6.hir: $(MRUSTC) LIBS
#	$(MINICARGO) $(RUSTCSRC)src/vendor/serde --vendor-dir $(RUSTCSRC)src/vendor --output-dir $(dir $@) -L $(OUTDIR)
$(OUTDIR)cargo-build/libgit2-0_6_6.hir: $(MRUSTC) LIBS
	$(MINICARGO) $(RUSTCSRC)src/vendor/git2 --vendor-dir $(RUSTCSRC)src/vendor --output-dir $(dir $@) -L $(OUTDIR) --features ssh,https,curl,openssl-sys,openssl-probe
$(OUTDIR)cargo-build/libserde_json-1_0_2.hir: $(MRUSTC) LIBS
	$(MINICARGO) $(RUSTCSRC)src/vendor/serde_json --vendor-dir $(RUSTCSRC)src/vendor --output-dir $(dir $@) -L $(OUTDIR)
$(OUTDIR)cargo-build/libcurl-0_4_6.hir: $(MRUSTC) LIBS
	$(MINICARGO) $(RUSTCSRC)src/vendor/curl --vendor-dir $(RUSTCSRC)src/vendor --output-dir $(dir $@) -L $(OUTDIR)
$(OUTDIR)cargo-build/libterm-0_4_5.hir: $(MRUSTC) LIBS
	$(MINICARGO) $(RUSTCSRC)src/vendor/term --vendor-dir $(RUSTCSRC)src/vendor --output-dir $(dir $@) -L $(OUTDIR)
