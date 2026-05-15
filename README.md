# mamba-vs-transformer-edge

Benchmarking Mamba (SSM) against Transformer at matched parameter sizes on consumer Apple Silicon — MacBook (M4 Max) and iPhone Air — with detailed memory profiling.

## Hypothesis

Mamba's constant per-token state and decode time should manifest as a structural advantage on memory-constrained iPhones at long context. Specifically:

1. At short context (≤ 256 tokens) decode throughput should be comparable between matched-size Mamba and Transformer.
2. At long context (≥ 4k tokens) Transformer's KV-cache grows linearly with context length; Mamba's state stays flat (`d_inner × d_state` per layer). On iPhone this shows up as:
   - Mamba: flat ms-per-token, flat physical footprint
   - Transformer: growing ms-per-token, memory pressure / jetsam at the edge

## Model pairs

Matched roughly by parameter count, both using mlx-swift / mamba-metal-swift on Apple Silicon:

| target size | Mamba | Transformer |
|---|---|---|
| ~130 M | `state-spaces/mamba-130m-hf` | `mlx-community/SmolLM-135M-Instruct-4bit` |
| ~700 M | `state-spaces/mamba-790m-hf` | `mlx-community/Qwen2.5-0.5B-Instruct-4bit` |
| ~1.3 B | `state-spaces/mamba-1.4b-hf` | `mlx-community/Llama-3.2-1B-Instruct-4bit` |
| ~3 B | `state-spaces/mamba-2.8b-hf` | `mlx-community/Qwen2.5-3B-Instruct-4bit` |

Quantization matters here — the Transformer side is 4-bit-quantized by default in mlx-lm registry, which gives them a memory advantage at the same parameter count. We will report both:
- **fp16 vs fp16** (apples-to-apples; iPhone may OOM at the larger sizes)
- **fp16 vs 4-bit** (deployment realistic; what one would actually ship)

## Devices

| device | hardware | unified mem | notes |
|---|---|---|---|
| MacBook | M4 Max | 36 GB | baseline; almost no memory pressure |
| iPhone Air | iPhone18,4 (Apple A19 Pro class) | ~8 GB | where the interesting failure modes happen |

## Metrics

Per `(device, model, context_length, run_idx)`:

| metric | how |
|---|---|
| prefill wall time | `Date()` around the prefill call |
| per-decoded-token wall time | `(t_end - t_start_decode) / n_new` |
| `phys_footprint` (iOS) | `task_info(TASK_VM_INFO)` |
| `os_proc_available_memory()` (iOS) | available before OS evicts |
| coherent output? (qualitative) | shared prompt list, manually inspected once per pair |

Sample context lengths: 64, 256, 1024, 4096, 8192, 16384 (where memory allows).

## Layout

```
mamba-vs-transformer-edge/
├── bench/                # Swift package
│   ├── BenchHarness/     # Library: measurement loop, JSON writer
│   ├── BenchTool/        # macOS CLI executable
│   └── BenchApp/         # iOS app (writes results to Documents/)
├── prompts/              # Reproducible prompt list
├── results/              # JSON results, per device + run
└── analyze/              # Python (numpy + matplotlib) to plot and tabulate
```

Results format (JSON, one file per run):

```json
{
  "device": "iPhone Air (A19 Pro)",
  "model": "state-spaces/mamba-1.4b-hf",
  "framework": "mamba-metal-swift",
  "prefill_tokens": 4096,
  "decode_tokens": 256,
  "prefill_seconds": 1.23,
  "decode_seconds_per_token": 0.007,
  "phys_footprint_mb_peak": 3200,
  "os_available_mem_mb_min": 1100,
  "killed_by_jetsam": false,
  "completed": true
}
```

## Sharing plan

Once results are stable:

1. Blog post on [createcentury.github.io/blog](https://createcentury.github.io/blog) (#5 or later) — full methodology, plots, code links.
2. X / LinkedIn thread with the killer chart and one-line claim.
3. HuggingFace community blog with reproducible repo link.
4. Short video of the iPhone running both models side-by-side.
5. (Conditional, if reception is good) arXiv preprint.

Dependencies on this project: [mamba-metal](https://github.com/createcentury/mamba-metal) (Python prototype) and [mamba-metal-swift](https://github.com/createcentury/mamba-metal-swift) (Swift port + iOS) for the Mamba side; mlx-swift / mlx-lm for the Transformer side.

## Status

🌅 Project initialised; design doc only. Implementation begins next.

## License

MIT
