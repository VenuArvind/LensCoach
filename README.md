# LensCoach 

LensCoach is a state-of-the-art AI photography assistant that combines real-time Computer Vision with deep-reasoning Large Language Models to help you take better photos.

## Architecture
LensCoach uses a **hybrid architecture** for maximum performance and flexibility:
- **LensCoachApp (SPM)**: The core logic library. Contains the CoreML aesthetic analysis engine, local LLM tip generator, and cloud provider integrations.
- **LensCoachNative (iOS App)**: A native SwiftUI wrapper that handles the camera session, UI/UX, and local persistence.

## Key Features
- **Hybrid Scoring**: Toggle between local **CoreML (15fps)** and **Cloud AI (GPT-4o/Gemini/Claude)**.
- **Proactive Coaching**: Real-time HUD tips generated every 2.5s to improve your composition.
- **Artistic Critique**: On-demand deep-dive reviews of your captures using multi-provider Vision models.
- **Portfolio Analytics**: Track your growth over time with interactive trend charts.

## On-Device Performance Benchmarks

To ensure a "Live" feel, LensCoach is highly optimized for Apple Silicon (A-series chips) and the Apple Neural Engine (ANE). Below are the validated metrics captured during on-device testing:

| Metric | Target | Result | Achievement |
| :--- | :--- | :--- | :--- |
| **Throughput (FPS)** | 30 FPS | **[TBD] FPS** | [Verified Performance] |
| **Inference Latency** | < 33ms | **[TBD] ms** | [ANE Optimization Level] |
| **Memory Footprint** | < 200MB | **[TBD] MB** | [Safety Margin] |
| **Thermal Stability** | Nominal | **[TBD]** | [Operating Stability] |

> [!IMPORTANT]
> These metrics are placeholders. To generate your own verified numbers, follow the [Validation Guide](./lenscoach_validation_guide.md) to extract telemetry from your physical device. Detailed per-sample performance graphs can be viewed in the interactive [Diagnostics Dashboard](./dashboard.html).

## Getting Started

### 1. Prerequisites
- **Xcode 15.0+**
- **iOS 16.0+** (Required for SwiftCharts)
- A physical iPhone (Recommended for the best AR-like experience)

### 2. Automated Model Setup
Due to file size limits, the 2.2GB LLM model is not stored in GitHub. You can download and place it automatically by running:

```zsh
chmod +x scripts/setup_models.sh
./scripts/setup_models.sh
```

This will download **Phi-3-mini** (2.2GB) and place it in the correct `LensCoachApp/Sources/Resources/` directory.

### 3. CoreML Model (Manual)
Since `FrameScore.mlmodelc` (~8MB) is your custom trained model, ensure you have placed it in:
`LensCoachApp/Sources/Resources/FrameScore.mlmodelc`

### 3. Open and Build
1. Clone the repository.
2. Open `LensCoachNative/LensCoachNative.xcodeproj`.
3. Ensure the `LensCoachApp` dependency (in the Project Navigator) is correctly resolved (it uses a relative local path).
4. Select your iPhone as the target and press **Cmd + R**.

## API Keys
LensCoach supports **Anthropic**, **Gemini**, and **OpenAI**. API keys are managed securely in-memory during your session. You will be prompted to enter a key when requesting a Cloud Critique or using Cloud Scoring mode.
