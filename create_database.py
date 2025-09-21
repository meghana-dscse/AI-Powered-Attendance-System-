import os
import cv2
import torch
import pickle
import numpy as np
import pandas as pd # <-- Import pandas
from ultralytics import YOLO
from facenet_pytorch import InceptionResnetV1

# --- Configuration ---
STUDENT_DATA_FOLDER = "dataset"
EMBEDDINGS_FILE = "student_embeddings.pkl"
YOLO_MODEL_PATH = "yolov8l-face.pt"
CSV_FILE = "students.csv" # <-- Add CSV file path

def create_embeddings():
    """Reads student data from CSV, finds matching images, and saves embeddings."""
    
    # --- Check for CSV file ---
    if not os.path.exists(CSV_FILE):
        print(f"FATAL ERROR: Student data file not found at '{CSV_FILE}'.")
        return
        
    student_df = pd.read_csv(CSV_FILE)
    print(f"Loaded {len(student_df)} student records from CSV.")

    # --- Initialize Models ---
    print("Initializing models...")
    yolo_model = YOLO(YOLO_MODEL_PATH)
    resnet = InceptionResnetV1(pretrained='vggface2').eval()
    print("Models initialized.")

    student_embeddings = {}

    for index, row in student_df.iterrows():
        roll_no = str(row['roll_no'])
        name = row['name']
        
        # Find the image file for the student (e.g., 101.jpg, 101.png)
        image_path = None
        for ext in [".jpg", ".png", ".jpeg"]:
            potential_path = os.path.join(STUDENT_DATA_FOLDER, roll_no + ext)
            if os.path.exists(potential_path):
                image_path = potential_path
                break
        
        if image_path is None:
            print(f"Warning: No image found for Roll No: {roll_no} ({name}). Skipping.")
            continue

        img = cv2.imread(image_path)
        if img is None:
            print(f"Warning: Could not read image {image_path}. Skipping.")
            continue

        results = yolo_model(img)
        boxes = results[0].boxes.xyxy.cpu().numpy()

        if len(boxes) == 0:
            print(f"Warning: No face detected for {roll_no} ({name}). Skipping.")
            continue

        x1, y1, x2, y2 = boxes[0].astype(int)
        face_crop = img[y1:y2, x1:x2]
        
        face_crop_rgb = cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB)
        face_crop_resized = cv2.resize(face_crop_rgb, (160, 160))

        face_tensor = torch.tensor(face_crop_resized).permute(2, 0, 1).unsqueeze(0).float() / 255.0

        with torch.no_grad():
            embedding = resnet(face_tensor).numpy()[0]
        
        # Store both name and embedding, keyed by roll number
        student_embeddings[roll_no] = {
            'name': name,
            'embedding': embedding
        }
        print(f"✔️ Registered embedding for {roll_no} - {name}")

    with open(EMBEDDINGS_FILE, "wb") as f:
        pickle.dump(student_embeddings, f)
    print(f"\n✅ All student embeddings saved to '{EMBEDDINGS_FILE}'")

if __name__ == "__main__":
    create_embeddings()
