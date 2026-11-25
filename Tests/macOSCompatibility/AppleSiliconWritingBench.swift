import Foundation
import CoreML

/// Uses fixed QA prompts only. Hardware enumeration is capability, not utilization evidence.
@main struct AppleSiliconWritingBench {
    @MainActor static func main() async throws {
        for device in MLComputeDevice.allComputeDevices {
            switch device {
            case .neuralEngine(let ane): print("COMPUTE DEVICE: ANE cores=\(ane.totalCoreCount) (capability only)")
            case .gpu(let gpu): print("COMPUTE DEVICE: GPU \(gpu.metalDevice.name)")
            case .cpu: print("COMPUTE DEVICE: CPU")
            @unknown default: print("COMPUTE DEVICE: unknown")
            }
        }
        print("THERMAL: \(ProcessInfo.processInfo.thermalState.rawValue) LOW POWER: \(ProcessInfo.processInfo.isLowPowerModeEnabled)")
        let readiness = WritingSuggestion.readiness()
        guard readiness.canGenerate else { throw WritingSuggestion.Failure(message: readiness.message) }
        let clock = ContinuousClock()
        for index in 0..<12 {
            let generator = WritingSuggestion.Generator()
            let warm = index % 4 == 1 || index % 4 == 2
            let preparationStart = clock.now
            var prepared = false
            if warm {
                prepared = generator.prepare()
                // Represents time spent editing before pressing Generate; report separately.
                try await Task.sleep(for: .seconds(2))
            }
            let lead = preparationStart.duration(to: clock.now)
            let start = clock.now
            var first: Duration?
            var partials = 0
            let result = try await generator.generate(from: "Sáng nay tôi đi dạo trong công viên.") { text in
                guard !text.isEmpty else { return }
                if first == nil { first = start.duration(to: clock.now) }
                partials += 1
            }
            guard let first, !result.isEmpty else { fatalError("No visible streamed result") }
            print("SAMPLE \(index) warm=\(warm) prepared=\(prepared) lead=\(lead) first=\(first) total=\(start.duration(to: clock.now)) partials=\(partials) characters=\(result.count)")
        }
    }
}
