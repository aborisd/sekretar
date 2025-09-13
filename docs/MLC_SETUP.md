MLC-LLM Integration (iOS)
=========================

This app is pre-wired to support on-device LLM via MLC-LLM. Below are safe, low‑friction steps to prepare the runtime/libs and link them in Xcode without building TVM from sources.

Prerequisites
- Xcode 15+
- Git + Git LFS
- Python 3.10+ and either `pipx` (recommended) or `pip`
- Optional: CMake (only if you choose to build from sources; not required for the safe path)

Safe install (no heavy TVM build)
---------------------------------

1) Install the CLI from prebuilt Python wheels (includes tvm runtime):

```
pipx install mlc-llm-nightly
# or: pip install --user mlc-llm-nightly
```

2) Clone mlc-llm and init submodules (for MLCSwift only, this does not compile TVM):

```
git clone https://github.com/mlc-ai/mlc-llm.git
cd mlc-llm
git submodule update --init --recursive
```

You may add it as a submodule under `third_party/mlc-llm` in this repo for convenience.

1) Clone mlc-llm and init submodules
------------------------------------

```
git clone https://github.com/mlc-ai/mlc-llm.git
cd mlc-llm
git submodule update --init --recursive
```

2) Package iOS runtime + model libs
-----------------------------------

In the root of this repo (calendAI) we provide `mlc-package-config.json` with a small default model.

Tip: for the very first run you can pick the lightest model in config (e.g., TinyLlama 1.1B) to minimize packaging time and disk usage.

```
# From the project root (calendAI)
export MLC_LLM_SOURCE_DIR=$(pwd)/third_party/mlc-llm
mlc_llm package
```

This creates `./dist/` with the following:
- `dist/lib`: `libmlc_llm.a`, `libmodel_iphone.a`, `libtvm_runtime.a`, `libtokenizers_cpp.a`, `libsentencepiece.a`, `libtokenizers_c.a`
- `dist/bundle`: `mlc-app-config.json` and (optionally) weights if you configured `bundle_weight: true`.

Notes
- No manual TVM build is required for this path.
- If your machine runs hot during packaging, limit parallelism: `export CMAKE_BUILD_PARALLEL_LEVEL=2`.

3) Add MLCSwift package and link libraries
------------------------------------------

- In Xcode add a local Swift package dependency pointing to `third_party/mlc-llm/ios/MLCSwift` (we track mlc-llm as a submodule).
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
