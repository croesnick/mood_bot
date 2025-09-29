# Local Inference

Running local language models on the Raspberry Pi.

## Issues

### `tokenizers` on Apple Silicon

With

```
{:bumblebee, "~> 0.6.3"},
{:nx, "~> 0.9.0"},
```

running `mix deps.get` yields

```
==> tokenizers
Compiling 18 files (.ex)

== Compilation error in file lib/tokenizers/native.ex ==
** (FunctionClauseError) no function clause matching in Access.fetch/2    
    
    The following arguments were given to Access.fetch/2:
    
        # 1
        true
    
        # 2
        :tokenizers
    
    Attempted function clauses (showing 5 out of 5):
    
        def fetch(%module{} = container, key)
        def fetch(map, key) when is_map(map)
        def fetch(list, key) when is_list(list) and is_atom(key)
        def fetch(list, key) when is_list(list)
        def fetch(nil, _key)
    
    (elixir 1.18.4) lib/access.ex:245: Access.fetch/2
    (elixir 1.18.4) lib/application.ex:663: Application.traverse_env/2
    (elixir 1.18.4) lib/application.ex:652: Application.fetch_compile_env/4
    (elixir 1.18.4) lib/application.ex:592: Application.compile_env/4
    lib/tokenizers/native.ex:8: (module)
```

**Interesting**: Somehow, the `nx` dependency collided with `bumblebee`.
Removing it did the job.

Just with bumblebee building the firmware for rpi5 as target:

```
==> tokenizers
Compiling 18 files (.ex)

15:17:48.801 [debug] Copying NIF from cache and extracting to /Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/priv/native/libex_tokenizers-v0.5.1-nif-2.15-aarch64-unknown-linux-gnu.so.tar.gz

15:17:48.818 [warning] The on_load function for module Elixir.Tokenizers.Native returned:
{:error,
 {:load_failed,
  ~c"Failed to load NIF library: 'dlopen(/Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/priv/native/libex_tokenizers-v0.5.1-nif-2.15-aarch64-unknown-linux-gnu.so, 0x0002): tried: '/Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/priv/native/libex_tokenizers-v0.5.1-nif-2.15-aarch64-unknown-linux-gnu.so' (slice is not valid mach-o file), '/System/Volumes/Preboot/Cryptexes/OS/Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/priv/native/libex_tokenizers-v0.5.1-nif-2.15-aarch64-unknown-linux-gnu.so' (no such file), '/Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/priv/native/libex_tokenizers-v0.5.1-nif-2.15-aarch64-unknown-linux-gnu.so' (slice is not valid mach-o file)'"}}
```

### No gemma-3

```
iex(1)> repo = {:hf, "google/gemma-3-270m", auth_token: "..."}
iex(2)> {:ok, model_info} = Bumblebee.load_model(repo, type: :bf16)
** (ArgumentError) could not match the class name "Gemma3ForCausalLM" to any of the supported models, please specify the :module and :architecture options
    (bumblebee 0.6.3) lib/bumblebee.ex:434: Bumblebee.do_load_spec/4
    (bumblebee 0.6.3) lib/bumblebee.ex:603: Bumblebee.maybe_load_model_spec/3
    (bumblebee 0.6.3) lib/bumblebee.ex:591: Bumblebee.load_model/2
    iex:3: (file)
```

Yeah, this one: <https://github.com/elixir-nx/bumblebee/issues/418>

Maybe kaitchup/Phi-3-mini-4k-instruct-gptq-4bit

### Cross-Compilation of `tokenizers`

Chain of deps: bumblebee -> nx -> tokenizers -> rustler_precompiled

Running `RUSTLER_PRECOMPILED_FORCE_BUILD_ALL=1 TOKENIZERS_BUILD=1 MIX_TARGET=rpi5 mix firmware` (for the env var, see <https://github.com/philss/rustler_precompiled/blob/main/lib/rustler_precompiled.ex#L58C8-L58C43>):

```shell
...
==> tokenizers
Compiling 18 files (.ex)
    Updating crates.io index
  Downloaded base64 v0.13.1
  Downloaded derive_builder v0.20.1
  Downloaded anyhow v1.0.89
  Downloaded darling_macro v0.20.10
  Downloaded bitflags v1.3.2
  Downloaded darling v0.20.10
  Downloaded monostate-impl v0.1.13
  Downloaded macro_rules_attribute-proc_macro v0.2.0
  Downloaded derive_builder_macro v0.20.1
  Downloaded itoa v1.0.11
  Downloaded unreachable v1.0.0
  Downloaded cfg-if v1.0.0
  Downloaded inventory v0.3.15
  Downloaded either v1.13.0
  Downloaded crossbeam-deque v0.8.5
  Downloaded proc-macro2 v1.0.86
  Downloaded void v1.0.2
  Downloaded monostate v0.1.13
  Downloaded rustler_sys v2.4.3
  Downloaded macro_rules_attribute v0.2.0
  Downloaded getrandom v0.2.15
  Downloaded derive_builder_core v0.20.1
  Downloaded thiserror-impl v1.0.64
  Downloaded rayon-cond v0.3.0
  Downloaded rustler_codegen v0.34.0
  Downloaded onig v6.4.0
  Downloaded zerocopy-derive v0.7.35
  Downloaded wasi v0.11.0+wasi-snapshot-preview1
  Downloaded once_cell v1.20.1
  Downloaded ppv-lite86 v0.2.20
  Downloaded pkg-config v0.3.31
  Downloaded smallvec v1.13.2
  Downloaded ryu v1.0.18
  Downloaded quote v1.0.37
  Downloaded log v0.4.22
  Downloaded darling_core v0.20.10
  Downloaded unicode_categories v0.1.1
  Downloaded thiserror v1.0.64
  Downloaded unicode-ident v1.0.13
  Downloaded crossbeam-utils v0.8.20
  Downloaded rustler v0.34.0
  Downloaded serde_derive v1.0.210
  Downloaded serde v1.0.210
  Downloaded rayon-core v1.12.1
  Downloaded cc v1.1.24
  Downloaded memchr v2.7.4
  Downloaded unicode-normalization-alignments v0.1.12
  Downloaded itertools v0.11.0
  Downloaded itertools v0.12.1
  Downloaded tokenizers v0.20.0
  Downloaded portable-atomic v1.9.0
  Downloaded rayon v1.10.0
  Downloaded zerocopy v0.7.35
  Downloaded esaxx-rs v0.1.10
  Downloaded serde_json v1.0.128
  Downloaded syn v2.0.79
  Downloaded regex v1.11.0
  Downloaded spm_precompiled v0.1.4
  Downloaded regex-automata v0.4.8
  Downloaded onig_sys v69.8.1
  Downloaded libc v0.2.159
  Downloaded 61 crates (5.7MiB) in 1.21s
Compiling crate ex_tokenizers in release mode (native/ex_tokenizers)
   Compiling proc-macro2 v1.0.86
   Compiling unicode-ident v1.0.13
   Compiling shlex v1.3.0
   Compiling crossbeam-utils v0.8.20
   Compiling memchr v2.7.4
   Compiling strsim v0.11.1
   Compiling libc v0.2.159
   Compiling ident_case v1.0.1
   Compiling fnv v1.0.7
   Compiling serde v1.0.210
   Compiling cc v1.1.24
   Compiling regex-syntax v0.8.5
   Compiling pkg-config v0.3.31
   Compiling aho-corasick v1.1.3
   Compiling either v1.13.0
   Compiling cfg-if v1.0.0
   Compiling byteorder v1.5.0
   Compiling rayon-core v1.12.1
   Compiling paste v1.0.15
   Compiling minimal-lexical v0.2.1
   Compiling void v1.0.2
   Compiling serde_json v1.0.128
   Compiling onig_sys v69.8.1
   Compiling esaxx-rs v0.1.10
   Compiling crossbeam-epoch v0.9.18
   Compiling quote v1.0.37
   Compiling syn v2.0.79
   Compiling regex-automata v0.4.8
   Compiling crossbeam-deque v0.8.5
   Compiling getrandom v0.2.15
   Compiling thiserror v1.0.64
   Compiling rand_core v0.6.4
warning: onig_sys@69.8.1: aarch64-nerves-linux-gnu-gcc: error: unrecognized command-line option '-arch'; did you mean '-march='?
warning: onig_sys@69.8.1: aarch64-nerves-linux-gnu-gcc: error: unrecognized command-line option '-mmacosx-version-min=15.5'
error: failed to run custom build command for `onig_sys v69.8.1`

Caused by:
  process didn't exit successfully: `/Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/native/ex_tokenizers/release/build/onig_sys-882a4d0c597dc06c/build-script-build` (exit status: 1)
  --- stdout
  cargo:rerun-if-env-changed=RUSTONIG_DYNAMIC_LIBONIG
  cargo:rerun-if-env-changed=RUSTONIG_STATIC_LIBONIG
  cargo:rerun-if-env-changed=RUSTONIG_SYSTEM_LIBONIG
  OUT_DIR = Some(/Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/native/ex_tokenizers/release/build/onig_sys-9c1fc0678c44f611/out)
  TARGET = Some(aarch64-apple-darwin)
  OPT_LEVEL = Some(3)
  HOST = Some(aarch64-apple-darwin)
  cargo:rerun-if-env-changed=CC_aarch64-apple-darwin
  CC_aarch64-apple-darwin = None
  cargo:rerun-if-env-changed=CC_aarch64_apple_darwin
  CC_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=HOST_CC
  HOST_CC = None
  cargo:rerun-if-env-changed=CC
  CC = Some(/Users/crntng/.nerves/artifacts/nerves_toolchain_aarch64_nerves_linux_gnu-darwin_arm-13.2.0/bin/aarch64-nerves-linux-gnu-gcc)
  RUSTC_WRAPPER = None
  cargo:rerun-if-env-changed=CC_ENABLE_DEBUG_OUTPUT
  cargo:rerun-if-env-changed=CRATE_CC_NO_DEFAULTS
  CRATE_CC_NO_DEFAULTS = None
  DEBUG = Some(false)
  CARGO_CFG_TARGET_FEATURE = Some(aes,crc,dit,dotprod,dpb,dpb2,fcma,fhm,flagm,fp16,frintts,jsconv,lor,lse,neon,paca,pacg,pan,pmuv3,ras,rcpc,rcpc2,rdm,sb,sha2,sha3,ssbs,vh)
  cargo:rerun-if-env-changed=MACOSX_DEPLOYMENT_TARGET
  MACOSX_DEPLOYMENT_TARGET = None
  cargo:rerun-if-env-changed=CFLAGS_aarch64-apple-darwin
  CFLAGS_aarch64-apple-darwin = None
  cargo:rerun-if-env-changed=CFLAGS_aarch64_apple_darwin
  CFLAGS_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=HOST_CFLAGS
  HOST_CFLAGS = None
  cargo:rerun-if-env-changed=CFLAGS
  CFLAGS = Some(-mabi=lp64 -Wl,-z,max-page-size=4096 -Wl,-z,common-page-size=4096 -fstack-protector-strong -mcpu=cortex-a76 -fPIE -pie -Wl,-z,now -Wl,-z,relro -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64  -pipe -O2 --sysroot /Users/crntng/.nerves/artifacts/nerves_system_rpi5-portable-0.6.2/staging)
  cargo:rerun-if-env-changed=CC_SHELL_ESCAPED_FLAGS
  CC_SHELL_ESCAPED_FLAGS = None
  cargo:warning=aarch64-nerves-linux-gnu-gcc: error: unrecognized command-line option '-arch'; did you mean '-march='?
  cargo:warning=aarch64-nerves-linux-gnu-gcc: error: unrecognized command-line option '-mmacosx-version-min=15.5'

  --- stderr


  error occurred: Command env -u IPHONEOS_DEPLOYMENT_TARGET "/Users/crntng/.nerves/artifacts/nerves_toolchain_aarch64_nerves_linux_gnu-darwin_arm-13.2.0/bin/aarch64-nerves-linux-gnu-gcc" "-O3" "-ffunction-sections" "-fdata-sections" "-fPIC" "-arch" "arm64" "-mmacosx-version-min=15.5" "-I" "/Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/native/ex_tokenizers/release/build/onig_sys-9c1fc0678c44f611/out" "-I" "oniguruma/src" "-mabi=lp64" "-Wl,-z,max-page-size=4096" "-Wl,-z,common-page-size=4096" "-fstack-protector-strong" "-mcpu=cortex-a76" "-fPIE" "-pie" "-Wl,-z,now" "-Wl,-z,relro" "-D_LARGEFILE_SOURCE" "-D_LARGEFILE64_SOURCE" "-D_FILE_OFFSET_BITS=64" "-pipe" "-O2" "--sysroot" "/Users/crntng/.nerves/artifacts/nerves_system_rpi5-portable-0.6.2/staging" "-DHAVE_UNISTD_H=1" "-DHAVE_SYS_TYPES_H=1" "-DHAVE_SYS_TIME_H=1" "-o" "/Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/native/ex_tokenizers/release/build/onig_sys-9c1fc0678c44f611/out/c77b18e714869709-regexec.o" "-c" "oniguruma/src/regexec.c" with args aarch64-nerves-linux-gnu-gcc did not execute successfully (status code exit status: 1).


warning: build failed, waiting for other jobs to finish...
warning: esaxx-rs@0.1.10: aarch64-nerves-linux-gnu-g++: error: unrecognized command-line option '-arch'; did you mean '-march='?
warning: esaxx-rs@0.1.10: aarch64-nerves-linux-gnu-g++: error: unrecognized command-line option '-mmacosx-version-min=15.5'
warning: esaxx-rs@0.1.10: aarch64-nerves-linux-gnu-g++: error: unrecognized command-line option '-stdlib=libc++'
error: failed to run custom build command for `esaxx-rs v0.1.10`

Caused by:
  process didn't exit successfully: `/Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/native/ex_tokenizers/release/build/esaxx-rs-799f876dd255863b/build-script-build` (exit status: 1)
  --- stdout
  OUT_DIR = Some(/Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/native/ex_tokenizers/release/build/esaxx-rs-be4e7a0d3c1c9605/out)
  TARGET = Some(aarch64-apple-darwin)
  OPT_LEVEL = Some(3)
  HOST = Some(aarch64-apple-darwin)
  cargo:rerun-if-env-changed=CXX_aarch64-apple-darwin
  CXX_aarch64-apple-darwin = None
  cargo:rerun-if-env-changed=CXX_aarch64_apple_darwin
  CXX_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=HOST_CXX
  HOST_CXX = None
  cargo:rerun-if-env-changed=CXX
  CXX = Some(/Users/crntng/.nerves/artifacts/nerves_toolchain_aarch64_nerves_linux_gnu-darwin_arm-13.2.0/bin/aarch64-nerves-linux-gnu-g++)
  RUSTC_WRAPPER = None
  cargo:rerun-if-env-changed=CC_ENABLE_DEBUG_OUTPUT
  cargo:rerun-if-env-changed=CRATE_CC_NO_DEFAULTS
  CRATE_CC_NO_DEFAULTS = None
  DEBUG = Some(false)
  CARGO_CFG_TARGET_FEATURE = Some(aes,crc,dit,dotprod,dpb,dpb2,fcma,fhm,flagm,fp16,frintts,jsconv,lor,lse,neon,paca,pacg,pan,pmuv3,ras,rcpc,rcpc2,rdm,sb,sha2,sha3,ssbs,vh)
  cargo:rerun-if-env-changed=MACOSX_DEPLOYMENT_TARGET
  MACOSX_DEPLOYMENT_TARGET = None
  cargo:rerun-if-env-changed=CXXFLAGS_aarch64-apple-darwin
  CXXFLAGS_aarch64-apple-darwin = None
  cargo:rerun-if-env-changed=CXXFLAGS_aarch64_apple_darwin
  CXXFLAGS_aarch64_apple_darwin = None
  cargo:rerun-if-env-changed=HOST_CXXFLAGS
  HOST_CXXFLAGS = None
  cargo:rerun-if-env-changed=CXXFLAGS
  CXXFLAGS = Some(-mabi=lp64 -Wl,-z,max-page-size=4096 -Wl,-z,common-page-size=4096 -fstack-protector-strong -mcpu=cortex-a76 -fPIE -pie -Wl,-z,now -Wl,-z,relro -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64  -pipe -O2 --sysroot /Users/crntng/.nerves/artifacts/nerves_system_rpi5-portable-0.6.2/staging)
  cargo:rerun-if-env-changed=CC_SHELL_ESCAPED_FLAGS
  CC_SHELL_ESCAPED_FLAGS = None
  cargo:warning=aarch64-nerves-linux-gnu-g++: error: unrecognized command-line option '-arch'; did you mean '-march='?
  cargo:warning=aarch64-nerves-linux-gnu-g++: error: unrecognized command-line option '-mmacosx-version-min=15.5'
  cargo:warning=aarch64-nerves-linux-gnu-g++: error: unrecognized command-line option '-stdlib=libc++'

  --- stderr


  error occurred: Command env -u IPHONEOS_DEPLOYMENT_TARGET "/Users/crntng/.nerves/artifacts/nerves_toolchain_aarch64_nerves_linux_gnu-darwin_arm-13.2.0/bin/aarch64-nerves-linux-gnu-g++" "-O3" "-ffunction-sections" "-fdata-sections" "-fPIC" "-arch" "arm64" "-mmacosx-version-min=15.5" "-I" "src" "-mabi=lp64" "-Wl,-z,max-page-size=4096" "-Wl,-z,common-page-size=4096" "-fstack-protector-strong" "-mcpu=cortex-a76" "-fPIE" "-pie" "-Wl,-z,now" "-Wl,-z,relro" "-D_LARGEFILE_SOURCE" "-D_LARGEFILE64_SOURCE" "-D_FILE_OFFSET_BITS=64" "-pipe" "-O2" "--sysroot" "/Users/crntng/.nerves/artifacts/nerves_system_rpi5-portable-0.6.2/staging" "-std=c++11" "-stdlib=libc++" "-o" "/Users/crntng/private/mood_bot/_build/rpi5_dev/lib/tokenizers/native/ex_tokenizers/release/build/esaxx-rs-be4e7a0d3c1c9605/out/2e40c9e35e9506f4-esaxx.o" "-c" "src/esaxx.cpp" with args aarch64-nerves-linux-gnu-g++ did not execute successfully (status code exit status: 1).



== Compilation error in file lib/tokenizers/native.ex ==
** (RuntimeError) Rust NIF compile error (rustc exit code 101)
    (rustler 0.36.2) lib/rustler/compiler.ex:36: Rustler.Compiler.compile_crate/3
    lib/tokenizers/native.ex:8: (module)
could not compile dependency :tokenizers, "mix compile" failed. Errors may have been logged above. You can recompile this dependency with "mix deps.compile tokenizers --force", update it with "mix deps.update tokenizers" or clean it with "mix deps.clean tokenizers"
```

## exla compile issue on macOS

See: <https://github.com/elixir-nx/nx/issues/1599>

Solution:

```shell
brew install llvm@16
```

Add to `~/.zshrc`:

```plaintext
export LDFLAGS="-L/opt/homebrew/opt/llvm@16/lib/c++ -Wl,-rpath,/opt/homebrew/opt/llvm@16/lib/c++"
export CPPFLAGS="-I/opt/homebrew/opt/llvm@16/include"
export CXX="clang++ -std=c++11 -stdlib=libc++"
```

## Other Hardware?

[OrangePi Ultra](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-5-Ultra.html) sounds neat.
But there's [currently no support for nerves](https://elixirforum.com/t/project-orange-pi-5-plus-with-nerves/70050/5) yet.

[Raspberry Pi AI HAT+](https://www.berrybase.de/raspberry-pi-ai-hat-13-tops-hailo-8l-accelerator) also looks amazing.
But I have not found yet if exla with [`XLA_TARGET=tpu`](https://github.com/elixir-nx/xla?tab=readme-ov-file#xla_target) can actually use it.

## Runtime Notes

```plaintext
21:27:29.116 [info] Loading language model | pid=<0.1833.0> 
21:27:29.116 [info] Loading Bumblebee model | pid=<0.1833.0> 
21:28:39.035 [info] Bumblebee model loaded successfully | duration_ms=69920 pid=<0.1833.0> 
21:28:39.036 [info] Loading Bumblebee tokenizer | pid=<0.1833.0> 
21:28:39.975 [info] Bumblebee tokenizer loaded successfully | duration_ms=939 pid=<0.1833.0> 
21:28:39.975 [info] Loading Bumblebee generation config | pid=<0.1833.0> 
21:28:40.094 [info] Bumblebee generation config loaded successfully | duration_ms=119 pid=<0.1833.0> 
21:28:40.094 [info] Creating Bumblebee Text.generation serving | pid=<0.1833.0> 
21:28:40.094 [info] EXLA backend status | pid=<0.1833.0> 
21:28:40.098 [info] Bumblebee serving created successfully | duration_ms=5 pid=<0.1833.0> 
21:28:40.098 [info] Starting serving child process | pid=<0.1833.0> api_name=chat_model serving_name=chat_model.Serving.3 
21:29:14.495 [info] Started Nx.Serving process | pid=<0.1872.0> name=chat_model.Serving.3 
21:29:14.495 [info] Serving child started successfully | pid=<0.1833.0> api_name=chat_model serving_name=chat_model.Serving.3 
21:29:14.495 [info] Language model loading completed successfully | duration_ms=105379 pid=<0.1833.0> serving_name=chat_model.Serving.3 
21:29:14.495 [info] Model loaded successfully | pid=<0.1833.0>
```

## References

- [LLMs like DeepSeek on Raspberry Pi 5](https://buyzero.de/blogs/news/deepseek-on-raspberry-pi-5-16gb-a-step-by-step-guide-to-local-llm-inference)
- [How to Do Sentiment Analysis With Large Language Models](https://blog.jetbrains.com/pycharm/2024/12/how-to-do-sentiment-analysis-with-large-language-models/)
- [Sentiment analysis using BERT models](https://medium.com/@alexrodriguesj/sentiment-analysis-with-bert-a-comprehensive-guide-6d4d091eb6bb)
- [An overview on SLMs - Small Language Models](https://huggingface.co/blog/jjokah/small-language-model)
- [How Well Do LLMs Perform on a Raspberry Pi 5?](https://www.stratosphereips.org/blog/2025/6/5/how-well-do-llms-perform-on-a-raspberry-pi-5) -- very well-done overview!
- [AN LLM FOR THE RASPBERRY PI](https://hackaday.com/2025/05/10/an-llm-for-the-raspberry-pi/)
- [Nerves and firmware build](https://elixirforum.com/t/custom-nerves-firmware-for-rpi5-issues/67239)
- [Hailo AI Module](https://elixirforum.com/t/nerves-rpi5-hailo8-m-2-ai-module-support/68142/7)
- <https://github.com/vittoriabitton/nx_hailo/tree/main/nx_hailo>
- <https://www.raspberrypi.com/news/raspberry-pi-ai-hat/>
- [hailo-ai/hailo-rpi5-examples](https://github.com/hailo-ai/hailo-rpi5-examples)
- [Bumblebee model cache directory](https://hexdocs.pm/bumblebee/Bumblebee.html#cache_dir/0)
- [Fine tune Mistral 7B with the RTX 4090 and serve it with Nx](https://toranbillups.com/blog/archive/2023/10/21/fine-tune-mistral-and-serve-with-nx/?utm_source=elixir-merge)
- [Bumblebee: Slow load_model in GenServer, slow Nx.Serving.run in exs file](https://elixirforum.com/t/bumblebee-slow-load-model-in-genserver-slow-nx-serving-run-in-exs-file/71888)
