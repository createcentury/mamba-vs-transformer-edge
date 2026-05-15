// macOS CLI: run a Mamba-side benchmark and write JSON results.
//
// usage: BenchTool <model_hf_id> <prompt> <decode_tokens> <output_json>

import Foundation
import MLX
import MambaMetal
import Tokenizers
import BenchHarness

@main
struct BenchTool {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count >= 5 else {
            print("usage: BenchTool <model_hf_id> <prompt> <decode_tokens> <output_json>")
            exit(2)
        }
        let modelId = args[1]
        let prompt = args[2]
        let decodeTokens = Int(args[3]) ?? 50
        let outputPath = args[4]

        // Locate cached HF snapshot.
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let repoDir = modelId.replacingOccurrences(of: "/", with: "--")
        let snapBase = "\(home)/.cache/huggingface/hub/models--\(repoDir)/snapshots"
        let dirs = try FileManager.default.contentsOfDirectory(atPath: snapBase)
        guard let snap = dirs.first else {
            fatalError("no snapshot at \(snapBase) — download via Python first")
        }
        let dir = "\(snapBase)/\(snap)"

        let memBefore = MemoryProfile.sample()

        let t0 = Date()
        let (model, _) = try loadMambaHF(
            safetensorsURL: URL(fileURLWithPath: "\(dir)/model.safetensors"),
            configURL: URL(fileURLWithPath: "\(dir)/config.json")
        )
        let tokenizer = try await AutoTokenizer.from(
            modelFolder: URL(fileURLWithPath: dir),
            strict: false
        )
        let loadSeconds = Date().timeIntervalSince(t0)

        let memAfterLoad = MemoryProfile.sample()
        let tracker = PeakMemoryTracker()

        // Encode prompt
        let promptIds = tokenizer.encode(text: prompt)
        var ids = promptIds

        // Prefill: one forward over the prompt
        let prefillT0 = Date()
        let prefillInput = MLXArray(ids.map { Int32($0) }, [1, ids.count])
        var logits = model(prefillInput)
        eval(logits)
        let prefillSec = Date().timeIntervalSince(prefillT0)
        tracker.sample()

        // Decode (O(L^2) form; one full forward per new token. State caching is future work.)
        let decodeT0 = Date()
        var generated: [Int] = []
        for _ in 0..<decodeTokens {
            let lastLogits = logits[0..., -1, 0...]
            let next = MLX.argMax(lastLogits, axis: -1)
            eval(next)
            let nextId = Int(next.asArray(Int32.self)[0])
            generated.append(nextId)
            ids.append(nextId)
            let inp = MLXArray(ids.map { Int32($0) }, [1, ids.count])
            logits = model(inp)
            eval(logits)
            tracker.sample()
        }
        let decodeSec = Date().timeIntervalSince(decodeT0)

        let outText = tokenizer.decode(tokens: generated)

        // Build result
        var os_info = "macOS"
        #if os(iOS)
        os_info = "iOS"
        #endif
        var device = "macOS"
        var size = utsname()
        if uname(&size) == 0 {
            withUnsafePointer(to: &size.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    device = String(cString: $0)
                }
            }
        }

        var result = BenchResult(
            device: device, os: os_info, framework: "mamba-metal-swift", model: modelId,
            promptTokens: promptIds.count, decodeTokens: decodeTokens,
            loadSeconds: loadSeconds,
            prefillSeconds: prefillSec,
            decodeSecondsPerToken: decodeSec / Double(decodeTokens),
            memoryBefore: memBefore, memoryAfterLoad: memAfterLoad,
            memoryPeak: tracker.peak
        )
        result.completed = true
        result.output = outText
        result.note = "tracker.availableMBMin not collected on macOS"

        try result.write(to: URL(fileURLWithPath: outputPath))

        print("✅ \(modelId)  prompt=\(promptIds.count)tok  decode=\(decodeTokens)tok")
        print("  load:    \(String(format: "%.2f", loadSeconds))s")
        print("  prefill: \(String(format: "%.0f", prefillSec * 1000))ms")
        print("  decode:  \(String(format: "%.1f", decodeSec * 1000 / Double(decodeTokens)))ms/tok  (\(String(format: "%.1f", Double(decodeTokens) / decodeSec)) tok/s)")
        print("  mem:     \(String(format: "%.0f", memAfterLoad.physFootprintMB))MB after load → \(String(format: "%.0f", tracker.peak.physFootprintMB))MB peak")
        print("  wrote:   \(outputPath)")
    }
}
