MLC-LLM Integration (iOS)
=========================

This app is pre-wired to support on-device LLM via MLC-LLM. Below are the steps to build the runtime/libs and link them in Xcode.

Prerequisites
- CMake >= 3.24
- Git + Git LFS
- Rust + Cargo
- Xcode 15+

1) Clone mlc-llm and init submodules
------------------------------------

```
git clone https://github.com/mlc-ai/mlc-llm.git
cd mlc-llm
git submodule update --init --recursive
```

2) Prepare `mlc_llm` package and build iOS runtime + model libs
----------------------------------------------------------------

In the root of this repo (calendAI), we provide `mlc-package-config.json` with a small default model (Gemma 2B q4f16_1).

```
# From the project root (calendAI)
export MLC_LLM_SOURCE_DIR=/absolute/path/to/mlc-llm
mlc_llm package
```

This creates `./dist/` with the following:
- `dist/lib`: `libmlc_llm.a`, `libmodel_iphone.a`, `libtvm_runtime.a`, `libtokenizers_cpp.a`, `libsentencepiece.a`, `libtokenizers_c.a`
- `dist/bundle`: `mlc-app-config.json` and (optionally) weights if you configured `bundle_weight: true`.

3) Add MLCSwift package and link libraries
------------------------------------------

- In Xcode add a local Swift package dependency pointing to `mlc-llm/ios/MLCSwift`.
- Target → Build Settings:
  - Library Search Paths: `$(PROJECT_DIR)/dist/lib`
  - Other Linker Flags:
    - `-Wl,-all_load`
    - `-lmodel_iphone -lmlc_llm -ltvm_runtime -ltokenizers_cpp -lsentencepiece -ltokenizers_c`
- Target → Build Phases:
  - Copy `dist/bundle` into your app resources (so `mlc-app-config.json` is inside the app bundle).

4) Run
------

Build and run on a Simulator or Device. The provider `MLCLLMProvider` will attempt to load the engine when `MLCSwift` is available. Until then, it falls back to a local heuristic provider.

Code Reference
- Provider skeleton: `calendAI/MLCLLMProvider.swift`
- Model manager: `calendAI/ModelManager.swift`
- Provider factory: `calendAI/AIProviderFactory.swift`
- Settings toggle (.mlc): `calendAI/SettingsViewModel.swift`
- Injection point: `calendAI/AIIntentService.swift`

