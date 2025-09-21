# 📌 Attendify: AI-Powered Smart Attendance System

**Attendify** is a modern, multi-platform solution designed to automate attendance marking using advanced facial recognition.  
This system leverages a powerful **Python backend** with state-of-the-art deep learning models and provides intuitive interfaces through both a **secure web portal** and a **cross-platform mobile application**.  

By utilizing the **YOLOv8l face detection** model, Attendify delivers **robust performance** even in challenging classroom environments.

---

## 📸 Screenshots

### Login Screen  
![Login Screen](path/to/login_screenshot.png)  

### Web Dashboard  
![Web Dashboard](path/to/web_dashboard_screenshot.png)  

### Mobile App  
![Mobile App](path/to/mobile_app_screenshot.png)  

- Secure login portal for authorized users.  
- Main dashboard for enrolling students and marking attendance.  
- On-the-go attendance with Flutter.  

---

## ✨ Features

- **High-Accuracy Face Recognition**  
  Uses **YOLOv8l** for robust detection and **FaceNet** for precise recognition.

- **Dual Platform Access**  
  - **Web Portal**: Secure dashboard for student enrollment, attendance marking from a class photo, and viewing records.  
  - **Flutter Mobile App**: Cross-platform app for Android/iOS with all core features.  

- **Dynamic Student Enrollment**  
  Add students via web or mobile with name, roll number, and photo. AI pipeline processes and stores their unique **faceprint**.  

- **Automated Attendance Reporting**  
  Upload a group photo → System detects faces, marks attendance, and overlays results on the image.  

- **Secure Authentication**  
  Web portal protected with **session-based login system**.  

---

## 🛠️ Tech Stack & Architecture

Attendify is built on a **client-server architecture**, separating AI processing from user-facing applications.

### Backend
- **Framework:** Flask (Python)  
- **AI & CV:** OpenCV, PyTorch  
- **Face Detection:** YOLOv8l-face  
- **Face Recognition:** FaceNet (via `facenet-pytorch`, pre-trained on VGGFace2)  
- **Data Handling:** Pandas, NumPy  

### Frontend (Web Portal)
- **Framework:** HTML, CSS, JavaScript (served by Flask)  
- **Styling:** Tailwind CSS  

### Frontend (Mobile App)
- **Framework:** Flutter (Dart)  
- **HTTP Client:** `http` package  
- **Image Handling:** `image_picker`  

---

## 🚀 System Pipeline

### 📍 Enrollment Pipeline
1. User submits student name, roll number, and photo.  
2. YOLOv8l detects face.  
3. FaceNet generates **128-D embedding** (faceprint).  
4. Embedding + student details saved in database.  

### 📍 Attendance Marking Pipeline
1. User uploads group photo.  
2. YOLOv8l detects all faces.  
3. FaceNet generates embeddings.  
4. Embeddings compared with database using **Cosine Similarity**.  
5. Final attendance report + annotated image generated.  

---

## 📋 Getting Started

```bash
# ✅ Prerequisites
# - Python 3.8+
# - Flutter SDK
# - Git

# --------------------------------------------------
# 1. Clone the Repository
git clone https://github.com/your-username/attendify.git
cd attendify

# --------------------------------------------------
# 2. Backend Setup
cd backend_server
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Place student data in /data and students.csv
# Download yolov8l-face.pt model

# Initialize database
python create_database.py

# Start backend server
python app.py

# --------------------------------------------------
# 3. Flutter App Setup
cd ../frontend_app
flutter pub get

# Update _apiUrl in lib/main.dart with your local IP

# Run Flutter app
flutter run

📄 Usage

Web Portal: Open http://127.0.0.1:5000 in browser.
Default Login: teacher / password