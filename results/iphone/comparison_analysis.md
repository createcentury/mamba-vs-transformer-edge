# iPhone Air: Mamba vs Transformer (first comparison)

## Raw data

### Mamba 130m (fp32, mamba-metal-swift)

| n | tok/s | total | peak MB | marginal ms/tok |
|---|---:|---:|---:|---:|
| 50 | 62.8 | 0.80 s | 595 | — |
| 200 | 87.7 | 2.28 s | 595 | 9.9 |
| 400 | 89.5 | 4.47 s | 583 | 11.0 |

### SmolLM 135M (4-bit, mlx-swift-lm)

| n | tok/s | total | peak MB | marginal ms/tok |
|---|---:|---:|---:|---:|
| 50 | 299.2 | 0.17 s | 147 | — |
| 200 | 421.0 | 0.48 s | 149 | 2.1 |
| 400 | 366.6 | 1.09 s | 169 | 3.1 |

## What this comparison is and isn't

It is NOT a clean isolation of architecture. SmolLM is heavily quantized (4-bit) and the mlx-swift-lm implementation is heavily tuned by Apple. Mamba runs in fp32 with a custom kernel we wrote in a single session. Most of the surface gap is the **quantization** (8× compression on weights) plus **engineering maturity**.

What it does still surface:

- **Mamba's per-token cost is flat** (9.9 → 11.0 ms across 4× growth in `n_new`).
- **SmolLM's per-token cost is already growing** (2.1 → 3.1 ms across the same 4× growth). This is the early shoulder of the KV-cache cost curve.

## Where Mamba's structural advantage should appear

Long context, where Transformer's KV cache becomes large and per-token cost rises substantially. At `n_new = 50-400` tokens on iPhone, we are well below that crossover.

## Next experiments (in priority order)

1. **Match the quantization story.** Either quantize Mamba (4-bit / 8-bit) or use an unquantized Transformer (e.g. SmolLM-135M fp16). Otherwise apples-to-oranges.
2. **Push `n_new` much higher** — 1024, 4096, 8192. Mamba's flat curve should pull ahead vs Transformer's growing curve.
3. **Long context prompts** — the headline claim is most about *context* length, not decoded length. Use a 4k-token prompt with a 100-token decode, measure prefill + memory carefully.
