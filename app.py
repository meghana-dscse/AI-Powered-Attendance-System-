import os
import cv2
import torch
import pickle
import numpy as np
import base64
import pandas as pd
from ultralytics import YOLO
from facenet_pytorch import InceptionResnetV1
from flask import Flask, request, jsonify, render_template, session, redirect, url_for, flash
import io
from datetime import datetime

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your_super_secret_key_change_this_later'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1000 * 1000 # 16MB max upload size

# --- Configuration ---
STUDENT_DATA_FOLDER = "data"
EMBEDDINGS_FILE = "student_embeddings.pkl"
YOLO_MODEL_PATH = "yolov8l-face.pt"
CSV_FILE = "students.csv"
MATCH_THRESHOLD = 0.6

# --- Load Models ---
yolo_model = YOLO(YOLO_MODEL_PATH)
resnet = InceptionResnetV1(pretrained='vggface2').eval()
try:
    with open(EMBEDDINGS_FILE, "rb") as f:
        student_embeddings = pickle.load(f)
except FileNotFoundError:
    student_embeddings = {}
    print(f"Warning: {EMBEDDINGS_FILE} not found. Starting with empty embeddings.")

# --- Utility Function ---
def get_embedding(image_bytes):
    data = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if img is None: return None, "Could not decode image."
    results = yolo_model(img)
    boxes = results[0].boxes.xyxy.cpu().numpy()
    if len(boxes) == 0: return None, "No face detected in the image."
    x1, y1, x2, y2 = boxes[0].astype(int)
    face_crop = img[y1:y2, x1:x2]
    face_crop_rgb = cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB)
    face_crop_resized = cv2.resize(face_crop_rgb, (160, 160))
    face_tensor = torch.tensor(face_crop_resized).permute(2, 0, 1).unsqueeze(0).float() / 255.0
    with torch.no_grad():
        embedding = resnet(face_tensor).numpy()[0]
    return embedding, "Success"

# --- Main Routes ---
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        if request.form.get('username') == 'teacher' and request.form.get('password') == 'password':
            session['logged_in'] = True
            return redirect(url_for('index'))
        else:
            flash('Invalid credentials. Please try again.', 'error')
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return redirect(url_for('login'))

@app.route('/')
def index():
    if not session.get('logged_in'):
        return redirect(url_for('login'))
    attendance_records = session.get('attendance_history', [])[::-1]
    return render_template('index.html', attendance_records=attendance_records)

# --- API Endpoints ---
@app.route('/mark_attendance', methods=['POST'])
def mark_attendance():
    # if not session.get('logged_in'): return jsonify({'error': 'Unauthorized'}), 401
    file = request.files.get('file')
    if not file: return jsonify({'error': 'No file part'}), 400

    in_memory_file = io.BytesIO()
    file.save(in_memory_file)
    data = np.frombuffer(in_memory_file.getvalue(), dtype=np.uint8)
    img = cv2.imdecode(data, cv2.IMREAD_COLOR)

    results = yolo_model(img)
    boxes = results[0].boxes.xyxy.cpu().numpy()
    present_students = []

    for box in boxes:
        x1, y1, x2, y2 = box.astype(int)
        face_crop = img[y1:y2, x1:x2]
        face_crop_rgb = cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB)
        face_crop_resized = cv2.resize(face_crop_rgb, (160, 160))
        face_tensor = torch.tensor(face_crop_resized).permute(2, 0, 1).unsqueeze(0).float() / 255.0
        with torch.no_grad():
            embedding = resnet(face_tensor).numpy()[0]

        best_match_roll_no = None
        best_match_score = -1
        for roll_no, student_data in student_embeddings.items():
            score = np.dot(embedding, student_data['embedding']) / (np.linalg.norm(embedding) * np.linalg.norm(student_data['embedding']))
            if score > best_match_score:
                best_match_score = score
                best_match_roll_no = str(roll_no)

        if best_match_score > MATCH_THRESHOLD:
            student_info = student_embeddings[best_match_roll_no]
            if not any(d['roll_no'] == best_match_roll_no for d in present_students):
                present_students.append({'roll_no': best_match_roll_no, 'name': student_info['name']})
            label = f"{student_info['name']} ({best_match_roll_no})"
            color = (0, 255, 0)
        else:
            label = "Unknown"
            color = (0, 0, 255)
        cv2.rectangle(img, (x1, y1), (x2, y2), color, 2)
        cv2.putText(img, label, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

    _, buffer = cv2.imencode('.jpg', img)
    img_str = base64.b64encode(buffer).decode('utf-8')
    
    all_students = [{'roll_no': str(rn), 'name': data['name']} for rn, data in student_embeddings.items()]

    if 'attendance_history' not in session: session['attendance_history'] = []
    new_record = {
        'time': datetime.now().strftime("%b %d, %Y %I:%M %p"),
        'present_count': len(present_students),
        'absent_count': len(all_students) - len(present_students),
        'total_count': len(all_students)
    }
    session['attendance_history'].append(new_record)
    if len(session['attendance_history']) > 5: session['attendance_history'].pop(0)
    session.modified = True

    return jsonify({
        'present_students': sorted(present_students, key=lambda x: x['name']),
        'all_students': sorted(all_students, key=lambda x: x['name']),
        'annotated_image': img_str
    })

@app.route('/add_student', methods=['POST'])
def add_student():
    if not session.get('logged_in'): return jsonify({'error': 'Unauthorized'}), 401
    if 'file' not in request.files or 'roll_no' not in request.form or 'name' not in request.form:
        return jsonify({'error': 'Missing data in the request'}), 400

    roll_no = request.form['roll_no']
    name = request.form['name']
    if str(roll_no) in student_embeddings:
        return jsonify({'error': f'Roll number {roll_no} already exists.'}), 409

    image_bytes = request.files['file'].read()
    embedding, message = get_embedding(image_bytes)
    if embedding is None: return jsonify({'error': message}), 400

    image_path = os.path.join(STUDENT_DATA_FOLDER, f"{roll_no}.jpg")
    with open(image_path, "wb") as f: f.write(image_bytes)
    with open(CSV_FILE, "a", newline='') as f: f.write(f"\n{roll_no},{name}")
    student_embeddings[str(roll_no)] = {'name': name, 'embedding': embedding}
    with open(EMBEDDINGS_FILE, "wb") as f: pickle.dump(student_embeddings, f)
    
    return jsonify({'success': f'Student {name} added successfully.'}), 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)