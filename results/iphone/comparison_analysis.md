# iPhone Air: Mamba vs Transformer — iterative findings

## Raw data (extended sweep, n = 50, 200, 400, 1000)

### Mamba 130m (fp32, mamba-metal-swift)

| n | tok/s | total | peak MB | marginal ms/tok |
|---|---:|---:|---:|---:|
| 50 | 63.7 | 0.78 s | 586 | — |
| 200 | 84.4 | 2.37 s | 578 | 10.6 |
| 400 | 91.3 | 4.38 s | 583 | 10.0 |
| **1000** | **90.7** | **11.02 s** | **590** | **11.1** |

→ Marginal cost is flat from 50 → 1000. Peak memory is flat. Mamba's constant-time decode property is cleanly visible.

### SmolLM 135M (4-bit, mlx-swift-lm)

| n | tok/s | total | peak MB | note |
|---|---:|---:|---:|---|
| 50 | 309.5 | 0.16 s | 652 | |
| 200 | 409.8 | 0.49 s | 656 | |
| 400 | 374.7 | 1.07 s | 667 | |
| **1000** | **1528.7 ⚠️** | **0.65 s** | **666** | **anomalous — see below** |

## Methodology caveats (important)

1. **Chunks vs tokens mismatch.** Our Mamba runner emits one stream chunk per generated token. `mlx-swift-lm`'s `ChatSession.streamResponse(to:)` emits chunks at arbitrary boundaries (often multi-token text fragments). Our `count >= maxNewTokens` break condition therefore terminates at very different effective token counts. The n=1000 SmolLM number (1528 chunks/s) is almost certainly an artefact of this — many of its later "chunks" were single-character pieces of degenerate output, hitting the break early in absolute time. To fix: use `streamDetails` and count `Generation.token` events instead.

2. **Quantization disparity.** SmolLM is 4-bit (≈ 67 MB of weights). Mamba is fp32 (≈ 520 MB). Eight-fold compression of the weights does most of the work for both speed (memory bandwidth) and footprint. Until Mamba is matched at 4-bit / 8-bit this is apples-to-oranges.

3. **Output quality is NOT equal.** Mamba 130m produces coherent continuations ("Tokyo, Japan. The city is located in…"). SmolLM 135M (4-bit Instruct) produces noticeably worse output for the same non-chat prompt. Plausible causes:
   - Pile (Mamba) is a stronger pretraining corpus than Cosmopedia (SmolLM) at this scale.
   - 4-bit quantization further degrades SmolLM.
   - SmolLM-Instruct is chat-tuned; a raw continuation prompt is out-of-distribution for it.

## What the comparison still tells us

- **Mamba 130m: flat per-token cost from n=50 to n=1000 on iPhone Air, ~11 ms/tok, ~590 MB resident.** That is a genuine demonstration of constant-state decode.
- **SmolLM 135M: per-token cost is already nudging up (2.1 → 2.6 ms/tok between n=50 and n=400)** before the chunk-counting artefact takes over. This is the early shoulder of the KV-cache curve.
- **Speed-only comparison is misleading.** A faster but lower-quality model is not a win.

## Next experiments (revised priorities)

1. **Fix token counting on the Transformer side** — use `streamDetails` and count `Generation.token` events.
2. **Match quantization** — quantize Mamba to 4-bit (`MLXFast`'s quantize helpers should make this easy) OR run an unquantized SmolLM if available.
3. **Add a quality metric** — perplexity on a held-out paragraph, or at minimum log the actual generated outputs so the qualitative gap is visible from results.
4. **Long context push** — once 1-3 are in place, sweep n_new up to 4k, 8k where Mamba's structural advantage actually appears.
