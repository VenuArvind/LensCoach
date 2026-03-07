import torch
import torchvision.transforms as T
import coremltools as ct
from torchvision.models import efficientnet_b0, EfficientNet_B0_Weights
from torch.utils.data import Dataset, DataLoader
from PIL import Image
import pandas as pd
import os
import argparse
import ssl

# Fix for macOS SSL certificate error when downloading weights
ssl._create_default_https_context = ssl._create_unverified_context

# 1. Setup Device (Apple Silicon GPU)
device = torch.device("mps") if torch.backends.mps.is_available() else torch.device("cpu")
print(f"Using device: {device}")

# 2. Dataset Definition
class AADBDataset(Dataset):
    def __init__(self, label_csv, img_dir, transform):
        df = pd.read_csv(label_csv)
        self.img_dir = img_dir
        self.transform = transform
        # Confirmed columns in Dataset.csv (including typos like 'Balacing')
        self.attr_cols = [
            'score', 'BalacingElements', 'ColorHarmony', 'Content', 'DoF', 
            'Light', 'MotionBlur', 'Object', 'Repetition', 'RuleOfThirds', 
            'Symmetry', 'VividColor'
        ]
        # Convert to list of dicts to avoid pandas recursion bugs in __getitem__ (Python 3.13)
        self.data = df[["ImageFile"] + self.attr_cols].to_dict('records')

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx, retries=0):
        if retries > 3:
            return torch.zeros((3, 224, 224)), torch.zeros(len(self.attr_cols))
            
        item = self.data[idx]
        # Match the EXACT folder name from the Kaggle unzip: 'datasetImages_warp256 2'
        img_path = os.path.join(self.img_dir, "datasetImages_warp256 2", item['ImageFile'].strip())
        
        try:
            img = Image.open(img_path).convert("RGB")
        except Exception as e:
            if retries == 0:
                print(f"FAILED to load: {img_path}. Error: {e}")
            return self.__getitem__((idx + 1) % len(self), retries + 1)
            
        img = self.transform(img)
        scores = torch.tensor([item[col] for col in self.attr_cols], dtype=torch.float32)
        return img, scores

# 3. Model Definition (12 outputs)
def get_model():
    model = efficientnet_b0(weights=EfficientNet_B0_Weights.DEFAULT)
    model.classifier = torch.nn.Sequential(
        torch.nn.Dropout(0.3),
        torch.nn.Linear(1280, 12) # 11 attributes + 1 score
    )
    for name, param in model.named_parameters():
        if not any(x in name for x in ["features.7", "features.8", "classifier"]):
            param.requires_grad = False
    return model.to(device)

def export_to_coreml(model, output_path):
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
        compute_units=ct.ComputeUnit.ALL
    )
    mlmodel.author = "LensCoach AI"
    mlmodel.short_description = "AADB Aesthetic Multi-Attribute Predictor"
    mlmodel.save(output_path)
    print(f"Model saved to {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data_dir", required=True)
    parser.add_argument("--epochs", type=int, default=1)
    args = parser.parse_args()

    # Transforms
    transform = T.Compose([
        T.Resize((224, 224)),
        T.ToTensor(),
        T.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ])

    # Data
    dataset = AADBDataset(os.path.join(args.data_dir, "Dataset.csv"), args.data_dir, transform)
    dataloader = DataLoader(dataset, batch_size=32, shuffle=True)

    # Model, Loss, Optimizer
    model = get_model()
    criterion = torch.nn.MSELoss()
    optimizer = torch.optim.Adam(model.parameters(), lr=1e-4)

    # Training Loop
    print(f"Starting training for {args.epochs} epoch(s)...")
    model.train()
    for epoch in range(args.epochs):
        running_loss = 0.0
        for i, (imgs, labels) in enumerate(dataloader):
            imgs, labels = imgs.to(device), labels.to(device)
            
            optimizer.zero_grad()
            outputs = model(imgs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item()
            if i % 10 == 0:
                print(f"Batch {i}, Loss: {loss.item():.4f}")
        
        print(f"Epoch {epoch+1} Complete. Avg Loss: {running_loss/len(dataloader):.4f}")

    # Export
    export_to_coreml(model, "FrameScore.mlpackage")
