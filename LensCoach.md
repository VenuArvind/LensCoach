# PROJECT 002 — FrameScore
### AI Photography Coach · Real-Time Composition · On-Device Aesthetics Scoring

**Platform:** iOS · Swift · SwiftUI  
**Dev Machine:** M5 MacBook Pro 16GB  
**Timeline:** 8 weeks  
**Budget:** ~$3–5 total  
**Target Roles:** Apple MLE · Google MLE · iOS SWE

---

## Overview

FrameScore is a live camera viewfinder that scores your composition in real-time before you press the shutter. A fine-tuned EfficientNet-B0 runs at 15fps on-device and returns 8 aesthetic attribute scores: rule of thirds, subject isolation, lighting quality, color harmony, depth of field, symmetry, leading lines, and overall balance. An exponential moving average filter keeps the scores stable as the camera moves. A small on-device LLM generates one actionable tip per 5 seconds. After capture, the user can tap to get a full artistic critique from Claude Opus 4 Vision.

No one has publicly shipped a clean iOS demo of real-time aesthetic scoring as a camera app. That makes it immediately memorable in a portfolio video and genuinely novel as a project.

The EMA smoother is itself an interview talking point: a signal processing choice that makes the product actually usable, independent of model accuracy. A model that is accurate but makes the UI jitter every frame is a failed product.

---

## Architecture

```
AVCaptureSession (30fps)
        |
        ▼
Frame sampler — every 2nd frame (→ effective 15fps)
        |
        ▼
CVPixelBuffer (fed directly — no UIImage conversion)
        |
        ▼
Preprocessing: resize to 224×224, normalize
        |
        ▼
EfficientNet-B0 CoreML (FLOAT16, Neural Engine)
→ 9 float outputs (8 attributes + 1 overall score)
        |
        ▼
EMA Smoother (α=0.3, per score)
→ Stabilized scores, ~3-frame lag
        |
        ▼
ScoreOverlayView (3 weakest scores shown as badges)
        |
        ▼
Phi-3-mini tip (max 1 per 5 sec, 20 token output)

[ User presses shutter ]
        |
        ▼
Full-resolution photo + on-device scores
        |
        ▼
Claude Opus 4 Vision API (user-initiated only)
→ Structured artistic critique
```

---

## Models

### EfficientNet-B0 fine-tuned on AADB — Real-Time Aesthetic Scorer

EfficientNet-B0 is chosen over MobileNetV3 because AADB is a multi-output regression task (8 continuous scores from 0 to 1), and EfficientNet's compound scaling gives better regression accuracy at nearly the same inference speed. The classifier head is replaced with a 9-output linear regression layer. The feature extractor is frozen except for the last 3 MBConv blocks, which are fine-tuned along with the new head.

Training uses MSE loss across all 8 attribute outputs simultaneously. Batch size 32, 30 epochs, AdamW with weight decay. Runs in roughly 1 hour on M5 Mac using PyTorch's MPS backend. After export to CoreML with FLOAT16 precision and `ComputeUnit.ALL`, inference runs on the Neural Engine at under 40ms per frame.

Target: Pearson correlation of 0.65–0.70 on the AADB test set, which is consistent with published baselines on this dataset.

### EMA Score Smoother — Signal Processing (No Model)

Exponential moving average with α=0.3 applied independently to each of the 8 score outputs per frame. Without this, scores change faster than the eye can parse as the camera moves and the UI feels completely broken even when the model is accurate. The implementation is three lines of Swift. α=0.3 gives approximately a 3-frame lag (200ms at 15fps) which feels natural for a live viewfinder.

```swift
for i in 0..<8 {
    smoothedScores[i] = 0.3 * newScores[i] + 0.7 * smoothedScores[i]
}
```

### Phi-3-mini Q4 (llama.cpp) — On-Device Tip Generator

Takes the current 8 smoothed scores and the identity of the lowest-scoring attribute. Generates one short actionable sentence using a fixed 60-token prompt template: "Camera viewfinder scores — [attribute: score, ...]. The weakest area is [attribute]. Give one short, specific tip to improve this shot." Output capped at 20 tokens. Rate-limited to one call per 5 seconds. Very low compute cost relative to the real-time CV pipeline running underneath it.

Download: `huggingface-cli download microsoft/Phi-3-mini-4k-instruct-gguf Phi-3-mini-4k-instruct-q4.gguf`. License: MIT.

### Claude Opus 4 Vision — Post-Capture Full Critique

Called on-demand only after the user taps "Full Critique" on the review screen. Sends the full-resolution photo as base64 alongside the on-device scores embedded in the prompt as context. The scores let Claude contrast its own visual analysis with the on-device model's assessment — a multi-model collaboration story that is interesting to explain in interviews. Cost per call: roughly $0.02–0.04.

---

## Datasets

**AADB (Aesthetics and Attributes Database)**
10,000 Flickr images rated by 5 independent workers each across 12 aesthetic attributes. You use 8 of the 12. Split: 8,500 train / 500 validation / 1,000 test. License: Creative Commons (the Flickr images). Access: github.com/aimerykong/deepImageAestheticsAnalysis — Google Drive download links are in the repo README. The 256×256 downsampled version is about 130MB and is sufficient for training.

**AVA (Aesthetic Visual Analysis)**
255,000 photos rated 1–10 by photographers. Optional: use the overall aesthetic score column to pre-train the overall quality head before switching to AADB multi-attribute fine-tuning. Available via multiple Kaggle mirrors (search "AVA aesthetic visual analysis"). Adds training time but can improve the overall score output. Not strictly required to get a working model.

**Your own iPhone photos (evaluation)**
Take 50+ test photos across diverse scene types: portrait, landscape, macro, architecture, street, indoor natural light, indoor artificial light. Use these to validate whether the live viewfinder's scores feel intuitively correct and whether the LLM tips feel actionable. This qualitative validation step matters because Pearson correlation alone does not tell you whether the product feels useful. Cost: zero.

---

## Training Script — M5 Mac

```python
# train_framescore.py
import torch
import torchvision
import coremltools as ct
from torchvision.models import efficientnet_b0, EfficientNet_B0_Weights
from torch.utils.data import Dataset, DataLoader
from PIL import Image
import pandas as pd

device = torch.device("mps")  # Apple Silicon GPU

class AADBDataset(Dataset):
    def __init__(self, csv_path, img_dir, transform):
        self.df = pd.read_csv(csv_path)
        self.img_dir = img_dir
        self.transform = transform

    def __len__(self):
        return len(self.df)

    def __getitem__(self, idx):
        row = self.df.iloc[idx]
        img = Image.open(f"{self.img_dir}/{row['filename']}").convert("RGB")
        img = self.transform(img)
        scores = torch.tensor(
            row[["rule_of_thirds","isolation","lighting","color_harmony",
                 "dof","symmetry","leading_lines","overall"]].values,
            dtype=torch.float32
        )
        return img, scores

transform_train = torchvision.transforms.Compose([
    torchvision.transforms.Resize(256),
    torchvision.transforms.RandomCrop(224),
    torchvision.transforms.RandomHorizontalFlip(),
    torchvision.transforms.ToTensor(),
    torchvision.transforms.Normalize([0.485,0.456,0.406],
                                      [0.229,0.224,0.225])
])

# Model: EfficientNet-B0 with 9-output regression head
model = efficientnet_b0(weights=EfficientNet_B0_Weights.DEFAULT)
model.classifier = torch.nn.Sequential(
    torch.nn.Dropout(0.3),
    torch.nn.Linear(1280, 9)   # 8 attributes + 1 overall score
)
model = model.to(device)

# Freeze all except last 3 MBConv blocks + classifier
for name, param in model.named_parameters():
    if not any(x in name for x in ["features.6","features.7",
                                    "features.8","classifier"]):
        param.requires_grad = False

criterion = torch.nn.MSELoss()
optimizer = torch.optim.AdamW(
    filter(lambda p: p.requires_grad, model.parameters()),
    lr=1e-4, weight_decay=1e-4
)
scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=30)

# Standard training loop across 30 epochs
# Roughly 1 hour on M5 Mac with MPS backend

# Export to CoreML after training
model.eval().cpu()
example_input = torch.randn(1, 3, 224, 224)
traced = torch.jit.trace(model, example_input)

mlmodel = ct.convert(
    traced,
    inputs=[ct.ImageType(
        name="image",
        shape=(1, 3, 224, 224),
        scale=1/(255.0 * 0.226),
        bias=[-0.485/0.229, -0.456/0.224, -0.406/0.225]
    )],
    compute_precision=ct.precision.FLOAT16,
    compute_units=ct.ComputeUnit.ALL   # enables Neural Engine
)
mlmodel.save("FrameScorer.mlpackage")
```

---

## Live Camera Pipeline — Key iOS Performance Details

**Do not convert CVPixelBuffer to UIImage.** Feed the CVPixelBuffer directly from AVCaptureVideoDataOutput into VNCoreMLRequest. Converting to UIImage involves a redundant memory copy that adds roughly 15ms per frame on A-series chips — that is 37% of your entire inference budget gone before the model even runs.

**Sample every other frame.** Use a frame counter with modulo 2 to run inference at 15fps from a 30fps capture. This halves the compute load with no perceptible difference to the user because score changes are already smoothed by the EMA filter.

**Use a dedicated serial DispatchQueue for inference.** Never run CoreML on the main thread. Create one DispatchQueue for Vision inference and a separate one for the LLM. The camera preview layer runs on the GPU independently so the UI never stalls.

---

## 8-Week Implementation Plan

**Week 1 — Custom Camera Viewfinder**

Build a custom camera view using AVFoundation directly — not UIImagePickerController or the SwiftUI Camera API, both of which are too limited for fine-grained pixel buffer access. Set up AVCaptureSession with a high-quality preset, AVCaptureVideoDataOutput for the live feed, and AVCapturePhotoOutput for stills. Render the preview using a Metal-backed CALayer. Add a capture button. Draw a rule-of-thirds grid overlay using CAShapeLayer as an immediate visual element. Add the frame sampler (modulo 2 counter) and confirm you are receiving 15fps CVPixelBuffer callbacks on the output delegate. The app should look like a real camera by the end of day one.

**Weeks 2–3 — AADB Download, Training, Export**

Download AADB from the GitHub Google Drive links in the repo README. Write a preprocessing script that resizes all images to 256×256 and saves them with original filenames intact. Parse the ratings CSV into per-image 8-float label vectors by averaging across the 5 rater scores. Run the training script above on your M5 Mac. Monitor validation MSE — should converge by epoch 20. After training, export to .mlpackage. Before adding to Xcode, run inference on 10 test images in Python and inspect the outputs: confirm scores are in a 0–1 range and that visually stronger images score higher than weaker ones. Fix any obvious calibration issues before moving to device.

**Week 4 — Wire CoreML into Live Camera**

Add the .mlpackage to Xcode. In the AVCaptureVideoDataOutputSampleBufferDelegate callback, extract the CVPixelBuffer on the inference DispatchQueue and run VNCoreMLRequest with the FrameScorer model. Implement the EMA smoother as three lines of Swift operating on a local [Float] array. Use @Published on a ViewModel to push the smoothed scores to SwiftUI. Build ScoreOverlayView showing the 3 weakest current scores as pill badges at the bottom of the viewfinder. Profile the full pipeline in Instruments: target under 40ms from pixel buffer received to overlay updated.

**Week 5 — On-Device LLM Tip Generation**

Integrate Phi-3-mini via llama.cpp following the same SPM setup. Write the prompt template, keeping it under 60 tokens. Apply DispatchQueue debounce to rate-limit at one call per 5 seconds. Render the tip as a card that slides in from the bottom with a 0.3s spring animation and auto-dismisses after 8 seconds. Add a tip history accessible by swiping up: last 5 tips generated with timestamps. This swipe-up gesture makes the UX feel intentional and gives you more to show in the demo video.

**Week 6 — Post-Capture Cloud Critique**

After capture, show a full-screen review view with the photo and a score bar chart for all 8 attributes. Add a "Get Full Critique" button. On tap, encode the photo as JPEG at 80% quality, convert to base64, and POST to the Anthropic API with Claude Opus 4 Vision. The prompt embeds the on-device scores alongside the image: "The on-device model scored this photo as follows: [scores]. Here is the image. Give a structured critique covering: technical execution, compositional strengths, lighting observations, and three specific improvement suggestions for the next shot." Parse the response into a CritiqueView with expandable labeled sections. Track all API calls and estimated costs in a local log accessible from the debug menu.

**Weeks 7–8 — Photo Library, Score Trends, Benchmarks, Demo**

Build a PhotoLibraryView grid showing past captured photos with their overall aesthetic score as a badge. Sort by score descending by default — seeing your highest and lowest-scoring shots ranked is immediately engaging and confirms the model is working correctly. Add a SwiftCharts line chart showing overall score over the last 20 captures: did your score improve as you practiced with the app? Produce the benchmark table: inference latency at 15fps, battery drain per hour in Instruments, Pearson r on AADB test set, on-device tip latency, cloud critique latency. Record the demo video: open app, slowly pan camera across a scene and show scores changing live, deliberately frame a bad composition and show low scores plus tip appearing, reframe and show scores rise, press the shutter, tap Full Critique and show Claude's analysis stream in. Target 2 minutes total.

---

## Interview Answer

"FrameScore runs an EfficientNet-B0 model fine-tuned on the AADB aesthetics dataset at 15 frames per second in the live camera viewfinder. I chose EfficientNet-B0 over MobileNetV3 because AADB is a multi-output regression task with 8 continuous outputs, and EfficientNet's compound scaling gives better regression accuracy at similar inference cost. I applied an exponential moving average filter to smooth scores across frames — a deliberate signal processing choice rather than an ML solution — because without it the UI was unusable despite the model being accurate. I feed CVPixelBuffers directly from AVCaptureVideoDataOutput into the CoreML request without converting to UIImage, which eliminates a redundant memory copy and saves 15ms per frame. The biggest lesson was that mobile ML product quality is determined as much by UX engineering as by model accuracy."

---

## Cost Breakdown

| Item | Cost |
|---|---|
| EfficientNet-B0 pretrained weights (torchvision) | $0 |
| AADB dataset (Creative Commons) | $0 |
| Phi-3-mini weights (MIT) | $0 |
| PyTorch, coremltools, torchvision | $0 |
| llama.cpp (MIT) | $0 |
| Anthropic API — post-capture critique, dev + demo (~100 user-triggered calls) | ~$3–5 |
| **Total** | **~$3–5** |
