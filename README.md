# LensCoach 📸🤖

LensCoach is a high-performance, on-device AI photography assistant that Bridges the gap between **real-time computer vision** and **deep-reasoning Generative AI**. It empowers photographers with live aesthetic feedback while maintaining absolute user privacy through a local-first security architecture.

---

## 🧠 Hybrid AI Engine
LensCoach utilizes a dual-engine approach to deliver zero-latency feedback without sacrificing creative depth:
- **Local Vision Engine**: An EfficientNet-B0 model optimized for the **Apple Neural Engine (ANE)**, providing 30+ FPS real-time scoring of 12 aesthetic attributes (Composition, Lighting, Symmetry, etc.).
- **Hybrid Generative Engine**: Orchestrates complex photographic critiques by toggling between:
  - **On-Device LLMs**: 4-bit quantized Small Language Models running via **Metal Performance Shaders (MPS)**.
  - **State-of-the-Art Cloud AI**: Native integration with **GPT-4o (OpenAI)**, **Claude 3 (Anthropic)**, and **Gemini 1.5 (Google)** for multi-modal artistic reasoning.

## 🛡️ Privacy-First Security
Designed for professionals, LensCoach implements a rigorous privacy layer:
- **On-Device PII Redaction**: Face detection and Gaussian blurring are performed locally *before* any frames touch the cloud.
- **EXIF Sanitization**: 100% of location, device, and personal metadata is stripped from images automatically.
- **Hardware Isolation**: No biometric or personal data is stored in the cloud.

## 📊 Analytics & Growth
- **Interactive Dashboards**: Real-time visualization of aesthetic growth using **SwiftCharts**, tracking improvement across sessions.
- **Persistent Portfolio**: Local persistence of captured masterpieces along with their AI-tagged aesthetic metadata.
- **Diagnostics Dashboard**: Integrated hardware telemetry suite providing verified proof of ANE utilization and memory stability.

---

## ⚡ Hardware Benchmarks (iPhone 13 Pro)
| Metric | Performance | Technical Significance |
| :--- | :---: | :--- |
| **Throughput (FPS)** | **~24 FPS** | Sustained real-time augmented overlay |
| **CoreML Latency** | **5.1 ms** | Ultra-efficient Neural Engine execution |
| **RAM Utilization** | **101 MB** | Lean footprint safe from Jetsam termination |
| **Thermal Efficiency**| **Nominal** | Optimized for zero thermal throttling |

---

## 🛠️ Getting Started

### 1. Model Preparation
Due to file size constraints, the 2.2GB LLM binaries are provisioned via script. Run the setup to download and verify the local intelligence layer:
```zsh
./scripts/setup_models.sh
```

### 2. Building the Project
1. Open `LensCoachNative/LensCoachNative.xcodeproj` in **Xcode 15+**.
2. Connect a physical iPhone (iOS 16+) to verify Neural Engine performance.
3. Select your device and press **Cmd + R**.

### 3. Integrated Diagnostics
To verify your own results, the app includes a `DiagnosticsManager`. Real-time telemetry is streamed to the Xcode console:
```text
DIAGNOSTICS | FPS: 30 | Latency: 5.1ms | Memory: 101.4MB | Thermal: 0
```
Interactive performance graphs can be generated using the [Diagnostics Dashboard](./dashboard.html).

---

## 🏗️ Technical Architecture
- **LensCoachApp (SPM)**: The logical core. Implements the `AestheticAnalyzer`, LLM wrappers, and Cloud Provider interfaces.
- **LensCoachNative**: SwiftUI application layer managing the camera session, persistence, and hardware-accelerated UI.

## 🔑 AI Providers
LensCoach supports flexible bring-your-own-key (BYOK) for Cloud AI. Configuration is managed securely in-session across **OpenAI**, **Anthropic**, and **Google**.
