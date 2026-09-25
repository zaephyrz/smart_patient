"""
Smart Patient Backend - Flask Version with Flask-Admin
"""
from flask import Flask, request, jsonify, g, send_file, render_template
from flask_cors import CORS
from flask_mail import Mail, Message
from flask_admin import Admin
from flask_admin.contrib.sqla import ModelView
from flask_admin.menu import MenuLink
from flask_admin.base import AdminIndexView
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timedelta
import sqlite3
import hashlib
import jwt
import os
import random
import string
from functools import wraps
import json
import secrets
import threading
from io import BytesIO
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.lib.utils import simpleSplit
import tempfile
import base64

# ========== CONFIGURATION ==========
class Config:
    BASE_DIR = os.path.abspath(os.path.dirname(__file__))
    DATABASE_PATH = os.path.join(BASE_DIR, "smart_patient.db")
    
    SECRET_KEY = os.getenv("SECRET_KEY", "smart-patient-secret-key-change-in-production-2024")
    DATABASE = DATABASE_PATH
    SQLALCHEMY_DATABASE_URI = f"sqlite:///{DATABASE_PATH}"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    ALLOWED_ORIGINS = [
        "http://localhost:3000", 
        "http://localhost:8080", 
        "http://localhost:57475", 
        "http://localhost:8000",
        "http://127.0.0.1:57475",
        "http://127.0.0.1:8000",
        "http://192.168.1.70:57475",
        "http://192.168.1.70:8000"
    ]
    
    MAIL_SERVER = os.getenv("MAIL_SERVER", "smtp.gmail.com")
    MAIL_PORT = int(os.getenv("MAIL_PORT", 587))
    MAIL_USE_TLS = os.getenv("MAIL_USE_TLS", "true").lower() == "true"
    MAIL_USERNAME = os.getenv("MAIL_USERNAME")
    MAIL_PASSWORD = os.getenv("MAIL_PASSWORD")
    MAIL_DEFAULT_SENDER = os.getenv("MAIL_DEFAULT_SENDER")
    FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:57475")
    
    UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024

# ========== CREATE APP ==========
app = Flask(__name__)
app.config.from_object(Config)

CORS(app, 
     origins=Config.ALLOWED_ORIGINS, 
     supports_credentials=True, 
     allow_headers=["Content-Type", "Authorization"], 
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])

db = SQLAlchemy(app)
os.makedirs(Config.UPLOAD_FOLDER, exist_ok=True)
mail = Mail(app)

# ========== MODELS ==========
class Patient(db.Model):
    __tablename__ = 'patients'
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(255), unique=True, nullable=False)
    phone = db.Column(db.String(50), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    pin_hash = db.Column(db.String(255), nullable=True)
    first_name = db.Column(db.String(100), nullable=False)
    last_name = db.Column(db.String(100), nullable=False)
    date_of_birth = db.Column(db.Date, nullable=False)
    gender = db.Column(db.String(20), nullable=True)
    blood_group = db.Column(db.String(10), nullable=True)
    address = db.Column(db.Text, nullable=True)
    emergency_contact_name = db.Column(db.String(255), nullable=True)
    emergency_contact_phone = db.Column(db.String(50), nullable=True)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"{self.first_name} {self.last_name} ({self.email})"

class Doctor(db.Model):
    __tablename__ = 'doctors'
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(255), unique=True, nullable=False)
    phone = db.Column(db.String(50), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    first_name = db.Column(db.String(100), nullable=False)
    last_name = db.Column(db.String(100), nullable=False)
    specialty = db.Column(db.String(100), nullable=False)
    license_number = db.Column(db.String(100), unique=True, nullable=False)
    hospital_affiliation = db.Column(db.String(255), nullable=False)
    consultation_fee = db.Column(db.Float, default=0.0)
    is_active = db.Column(db.Boolean, default=True)
    rating = db.Column(db.Float, default=0.0)
    profile_image = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"Dr. {self.first_name} {self.last_name} ({self.specialty})"

class Appointment(db.Model):
    __tablename__ = 'appointments'
    id = db.Column(db.Integer, primary_key=True)
    patient_id = db.Column(db.Integer, db.ForeignKey('patients.id'), nullable=False)
    doctor_id = db.Column(db.Integer, db.ForeignKey('doctors.id'), nullable=False)
    appointment_date = db.Column(db.DateTime, nullable=False)
    status = db.Column(db.String(50), default='scheduled')
    consultation_type = db.Column(db.String(50), default='in_person')
    symptoms = db.Column(db.Text, nullable=True)
    diagnosis = db.Column(db.Text, nullable=True)
    notes = db.Column(db.Text, nullable=True)
    is_telemedicine = db.Column(db.Boolean, default=False)
    telemedicine_room_id = db.Column(db.String(100), nullable=True)
    duration_minutes = db.Column(db.Integer, default=30)
    consultation_fee = db.Column(db.Float, default=0.0)
    is_confirmed = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    patient = db.relationship('Patient', backref=db.backref('appointments', lazy='joined'))
    doctor = db.relationship('Doctor', backref=db.backref('appointments', lazy='joined'))

    def __repr__(self):
        return f"Appointment #{self.id} - {self.appointment_date}"

class MedicalRecord(db.Model):
    __tablename__ = 'medical_records'
    id = db.Column(db.Integer, primary_key=True)
    patient_id = db.Column(db.Integer, db.ForeignKey('patients.id'), nullable=False)
    appointment_id = db.Column(db.Integer, db.ForeignKey('appointments.id'), nullable=True)
    record_type = db.Column(db.String(100), nullable=False)
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=True)
    file_name = db.Column(db.String(255), nullable=True)
    file_path = db.Column(db.String(500), nullable=True)
    file_size = db.Column(db.Integer, nullable=True)
    mime_type = db.Column(db.String(100), nullable=True)
    record_date = db.Column(db.Date, nullable=False)
    uploaded_at = db.Column(db.DateTime, default=datetime.utcnow)
    department = db.Column(db.String(100), nullable=True)
    attending_physician = db.Column(db.String(255), nullable=True)
    diagnosis_code = db.Column(db.String(50), nullable=True)
    icd10_code = db.Column(db.String(50), nullable=True)
    lab_results = db.Column(db.Text, nullable=True)
    vitals = db.Column(db.Text, nullable=True)
    medications = db.Column(db.Text, nullable=True)
    allergies = db.Column(db.Text, nullable=True)
    notes = db.Column(db.Text, nullable=True)

    patient = db.relationship('Patient', backref=db.backref('medical_records', lazy=True))
    appointment = db.relationship('Appointment', backref=db.backref('medical_records', lazy=True))

    def __repr__(self):
        return f"{self.record_type}: {self.title}"

class Notification(db.Model):
    __tablename__ = 'notifications'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, nullable=False)
    user_role = db.Column(db.String(50), nullable=False)
    title = db.Column(db.String(255), nullable=False)
    message = db.Column(db.Text, nullable=False)
    type = db.Column(db.String(50), default='info')
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"Notification {self.id} - {self.title}"

# ========== ADMIN VIEWS ==========
class CustomAdminIndexView(AdminIndexView):
    def is_visible(self):
        return False

class PatientModelView(ModelView):
    column_list = ['id', 'email', 'first_name', 'last_name', 'phone', 'is_active', 'created_at']
    column_searchable_list = ['email', 'first_name', 'last_name', 'phone']
    column_filters = ['is_active', 'created_at']

class DoctorModelView(ModelView):
    column_list = ['id', 'email', 'first_name', 'last_name', 'specialty', 'hospital_affiliation', 'is_active']
    column_searchable_list = ['email', 'first_name', 'last_name', 'specialty', 'hospital_affiliation']

class AppointmentModelView(ModelView):
    column_list = ['id', 'patient', 'doctor', 'appointment_date', 'status', 'consultation_type']

class MedicalRecordModelView(ModelView):
    column_list = ['id', 'patient', 'record_type', 'title', 'record_date', 'department', 'attending_physician']

# ========== INITIALIZE ADMIN ==========
admin = Admin(app, name='Smart Patient Admin', index_view=CustomAdminIndexView())
admin.add_view(PatientModelView(Patient, db.session))
admin.add_view(DoctorModelView(Doctor, db.session))
admin.add_view(AppointmentModelView(Appointment, db.session))
admin.add_view(MedicalRecordModelView(MedicalRecord, db.session))

admin.add_link(MenuLink(name='🏠 Back to App', url='/'))

# ========== HELPERS & PDF GENERATOR ==========
def send_async_email(msg):
    try:
        with app.app_context():
            mail.send(msg)
    except Exception as e:
        print(f"Failed to send email: {e}")

def send_email(recipient, subject, body, html_body=None):
    msg = Message(subject=subject, recipients=[recipient], body=body, html=html_body)
    threading.Thread(target=send_async_email, args=(msg,)).start()

def generate_reset_token(email):
    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=24)
    conn = sqlite3.connect(Config.DATABASE_PATH)
    cursor = conn.cursor()
    cursor.execute("DELETE FROM password_reset_tokens WHERE email = ?", (email,))
    cursor.execute('INSERT INTO password_reset_tokens (email, token, expires_at) VALUES (?, ?, ?)', (email, token, expires_at))
    conn.commit()
    conn.close()
    return token

def create_notification(user_id, user_role, title, message, type="info"):
    notif = Notification(user_id=user_id, user_role=user_role, title=title, message=message, type=type, is_read=False)
    db.session.add(notif)
    db.session.commit()
    return notif.id

def generate_professional_pdf(record_id, title, description, patient_id, record_type, record_date, 
                             department="N/A", attending_physician="N/A", diagnosis_code="N/A", 
                             icd10_code="N/A", lab_results="N/A", vitals="N/A", 
                             medications="N/A", allergies="N/A", notes="N/A"):
    buffer = BytesIO()
    try:
        c = canvas.Canvas(buffer, pagesize=letter)
        width, height = letter
        
        c.setFont("Helvetica-Bold", 20)
        c.setFillColorRGB(0.12, 0.53, 0.90)
        c.drawString(72, height - 54, "SMART MEDICAL HUB")
        
        c.setFont("Helvetica", 12)
        c.setFillColorRGB(0.3, 0.3, 0.3)
        c.drawString(72, height - 72, "Official Patient Medical Record")
        
        c.setStrokeColorRGB(0.12, 0.53, 0.90)
        c.setLineWidth(1.5)
        c.line(72, height - 82, width - 72, height - 82)
        
        y = height - 110
        c.setFont("Helvetica-Bold", 11)
        c.setFillColorRGB(0, 0, 0)
        c.drawString(72, y, "RECORD & CLINICAL METADATA")
        y -= 18
        
        c.setFont("Helvetica", 10)
        c.drawString(72, y, f"Record ID: #{record_id}    |    Type: {record_type}    |    Date: {record_date}")
        y -= 15
        c.drawString(72, y, f"Department: {department}")
        y -= 15
        c.drawString(72, y, f"Attending Physician: {attending_physician}")
        y -= 15
        c.drawString(72, y, f"Diagnosis Code: {diagnosis_code}    |    ICD-10 Code: {icd10_code}")
        
        y -= 25
        c.setFont("Helvetica-Bold", 11)
        c.drawString(72, y, f"TITLE: {title}")
        
        y = height - 230
        c.setFont("Helvetica-Bold", 11)
        c.drawString(72, y, "CLINICAL FINDINGS & NOTES")
        y -= 18
        
        c.setFont("Helvetica", 10)
        full_text = f"Description: {description}\n\nLab Results: {lab_results}\n\nVitals: {vitals}\n\nMedications: {medications}\n\nAllergies: {allergies}\n\nNotes: {notes}"
        lines = simpleSplit(full_text, "Helvetica", 10, width - 144)
        for line in lines:
            if y < 70:
                c.showPage()
                y = height - 50
                c.setFont("Helvetica", 10)
            c.drawString(72, y, line)
            y -= 14
        
        c.setFont("Helvetica-Oblique", 8)
        c.setFillColorRGB(0.5, 0.5, 0.5)
        c.drawString(72, 35, f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | Smart Medical Hub")
        
        c.save()
        buffer.seek(0)
        return buffer
    except Exception as e:
        print(f"PDF generation error: {e}")
        c = canvas.Canvas(buffer, pagesize=letter)
        c.drawString(100, 500, f"Medical Record #{record_id}: {title}")
        c.save()
        buffer.seek(0)
        return buffer

def generate_telemedicine_room_id():
    digits = ''.join(random.choices(string.digits, k=5))
    return f"SMH-{digits}"

def init_db():
    with app.app_context():
        db.create_all()
        
        patient = Patient.query.filter_by(email='patient@example.com').first()
        if not patient:
            patient = Patient(
                email='patient@example.com',
                phone='+1234567890',
                password_hash=hashlib.sha256('Patient123!'.encode()).hexdigest(),
                first_name='John',
                last_name='Doe',
                date_of_birth=datetime.strptime('1990-01-15', '%Y-%m-%d').date(),
                gender='Male',
                blood_group='A+',
                is_active=True
            )
            db.session.add(patient)
            db.session.commit()

        if Doctor.query.count() == 0:
            doc1 = Doctor(
                email='doctor.smith@hospital.com',
                phone='+1234567891',
                password_hash=hashlib.sha256('Doctor123!'.encode()).hexdigest(),
                first_name='Jane',
                last_name='Smith',
                specialty='Cardiology',
                license_number='LIC-2024-001',
                hospital_affiliation='Smart Medical Heart Center',
                consultation_fee=150.00
            )
            db.session.add(doc1)
            db.session.commit()

        if MedicalRecord.query.count() == 0 and patient:
            doc = Doctor.query.first()
            rec = MedicalRecord(
                patient_id=patient.id,
                record_type='Lab Report',
                title='Comprehensive Metabolic Panel',
                description='Routine annual checkup blood panel results.',
                record_date=datetime.now().date(),
                department='Pathology',
                attending_physician=f"Dr. {doc.first_name} {doc.last_name}" if doc else 'Dr. Jane Smith',
                diagnosis_code='Z00.00',
                icd10_code='Z00',
                lab_results='Glucose: 95 mg/dL, Cholesterol: 180 mg/dL',
                vitals='BP: 120/80, HR: 72 bpm',
                medications='None',
                allergies='None known',
                notes='Patient is in excellent health.',
                file_size=102400
            )
            db.session.add(rec)
            db.session.commit()

# ========== AUTH & SECURITY HELPERS ==========
def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

def create_token(user_id, email, role="patient"):
    payload = {
        "user_id": user_id,
        "email": email,
        "role": role,
        "exp": datetime.utcnow() + timedelta(days=7)
    }
    return jwt.encode(payload, Config.SECRET_KEY, algorithm="HS256")

def verify_token(token):
    try:
        return jwt.decode(token, Config.SECRET_KEY, algorithms=["HS256"])
    except Exception:
        return None

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({"error": "Authorization token required"}), 401
        token = auth_header.split(' ')[1]
        payload = verify_token(token)
        if not payload:
            return jsonify({"error": "Invalid or expired token"}), 401
        g.user_id = payload['user_id']
        g.user_email = payload['email']
        g.user_role = payload['role']
        return f(*args, **kwargs)
    return decorated

# ========== ROUTES ==========
@app.route('/')
def root():
    return jsonify({"message": "Smart Patient API", "status": "operational"})

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

@app.route('/api/auth/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        print(f"📝 Registration attempt: {data.get('email')}")  # Debug print
        
        # Validate required fields
        required = ['email', 'phone', 'password', 'first_name', 'last_name', 'date_of_birth']
        for field in required:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400
        
        # Check if user already exists
        existing = Patient.query.filter(
            (Patient.email == data['email']) | (Patient.phone == data['phone'])
        ).first()
        
        if existing:
            return jsonify({"error": "User with this email or phone already exists"}), 400
        
        # Create new patient
        patient = Patient(
            email=data['email'],
            phone=data['phone'],
            password_hash=hash_password(data['password']),
            first_name=data['first_name'],
            last_name=data['last_name'],
            date_of_birth=datetime.strptime(data['date_of_birth'], '%Y-%m-%d').date(),
            gender=data.get('gender'),
            blood_group=data.get('blood_group'),
            address=data.get('address'),
            emergency_contact_name=data.get('emergency_contact_name'),
            emergency_contact_phone=data.get('emergency_contact_phone')
        )
        
        db.session.add(patient)
        db.session.commit()
        print(f"✅ User registered: {patient.email} (ID: {patient.id})")
        
        # Generate token
        token = create_token(patient.id, patient.email, "patient")
        
        return jsonify({
            "message": "Registration successful",
            "token": token,
            "user": {
                "id": patient.id,
                "email": patient.email,
                "first_name": patient.first_name,
                "last_name": patient.last_name,
                "role": "patient"
            }
        }), 201
        
    except Exception as e:
        db.session.rollback()
        print(f"❌ Registration error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/auth/login', methods=['POST'])
def login():
    data = request.get_json()
    patient = Patient.query.filter_by(email=data.get('email')).first()
    if not patient or patient.password_hash != hash_password(data.get('password')):
        return jsonify({"error": "Invalid credentials"}), 401
    
    token = create_token(patient.id, patient.email, "patient")
    return jsonify({
        "message": "Login successful",
        "token": token,
        "user": {
            "id": patient.id,
            "email": patient.email,
            "first_name": patient.first_name,
            "last_name": patient.last_name,
            "role": "patient"
        }
    }), 200

@app.route('/api/auth/doctor/login', methods=['POST'])
def login_doctor():
    data = request.get_json()
    doctor = Doctor.query.filter_by(email=data.get('email')).first()
    if not doctor or doctor.password_hash != hash_password(data.get('password')):
        return jsonify({"error": "Invalid credentials"}), 401
    
    token = create_token(doctor.id, doctor.email, "doctor")
    return jsonify({
        "message": "Login successful",
        "token": token,
        "user": {
            "id": doctor.id,
            "email": doctor.email,
            "first_name": doctor.first_name,
            "last_name": doctor.last_name,
            "role": "doctor"
        }
    }), 200

@app.route('/api/auth/setup-pin', methods=['POST'])
@token_required
def setup_pin():
    data = request.get_json()
    patient = db.session.get(Patient, g.user_id)
    if not patient:
        return jsonify({"error": "Patient not found"}), 404
    patient.pin_hash = hash_password(data['pin'])
    db.session.commit()
    return jsonify({"message": "PIN setup successful"}), 200

@app.route('/api/doctors', methods=['GET'])
def get_doctors():
    doctors = Doctor.query.filter_by(is_active=True).all()
    result = []
    for doc in doctors:
        result.append({
            "id": doc.id,
            "first_name": doc.first_name,
            "last_name": doc.last_name,
            "full_name": f"Dr. {doc.first_name} {doc.last_name}",
            "specialty": doc.specialty,
            "hospital_affiliation": doc.hospital_affiliation,
            "consultation_fee": doc.consultation_fee,
            "rating": doc.rating,
            "profile_image": doc.profile_image,
        })
    return jsonify({"success": True, "doctors": result}), 200

# Add this route after the login routes in app.py

@app.route('/api/auth/forgot-password', methods=['POST'])
def forgot_password():
    try:
        data = request.get_json()
        
        if not data or 'email' not in data:
            return jsonify({"error": "Email required"}), 400
        
        # Check if user exists
        patient = Patient.query.filter_by(email=data['email']).first()
        if not patient:
            # For security, don't reveal if email exists or not
            return jsonify({
                "success": True,
                "message": "If an account exists with this email, a password reset link has been sent."
            }), 200
        
        # Generate reset token
        token = generate_reset_token(data['email'])
        
        # Generate both web and app links
        web_reset_link = f"{Config.FRONTEND_URL}/reset-password?token={token}&email={data['email']}"
        app_reset_link = f"smartpatient://reset-password?token={token}&email={data['email']}"
        
        # Send email with reset link
        html_body = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: linear-gradient(135deg, #4A90D9, #27AE60); color: white; padding: 20px; border-radius: 10px 10px 0 0; }}
                .content {{ background: #f9f9f9; padding: 20px; border-radius: 0 0 10px 10px; }}
                .button {{ display: inline-block; padding: 12px 24px; background: #4A90D9; color: white; text-decoration: none; border-radius: 5px; }}
                .app-link {{ color: #27AE60; text-decoration: none; }}
                .footer {{ text-align: center; margin-top: 20px; font-size: 12px; color: #999; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1 style="margin: 0;">🏥 Smart Medical Hub</h1>
                    <p style="margin: 5px 0 0 0;">Password Reset</p>
                </div>
                <div class="content">
                    <h2>Reset Your Password</h2>
                    <p>Hello {patient.first_name},</p>
                    <p>We received a request to reset your password. Click the button below to set a new password:</p>
                    
                    <p style="text-align: center; margin: 30px 0;">
                        <a href="{web_reset_link}" class="button">Reset Password</a>
                    </p>
                    
                    <p>If the button doesn't work, copy and paste this link into your browser:</p>
                    <p><a href="{web_reset_link}">{web_reset_link}</a></p>
                    
                    <hr>
                    
                    <p><strong>📱 Open in App:</strong></p>
                    <p>If you have the Smart Patient app installed, you can click this link to reset your password directly in the app:</p>
                    <p><a href="{app_reset_link}" class="app-link">{app_reset_link}</a></p>
                    
                    <p style="margin-top: 20px; color: #666;">This link will expire in 24 hours.</p>
                    <p style="color: #666;">If you didn't request this, please ignore this email.</p>
                </div>
                <div class="footer">
                    <p>&copy; 2024 Smart Medical Hub. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        send_email(
            recipient=data['email'],
            subject="Password Reset Request - Smart Patient",
            body=f"""
            Click the link to reset your password: {web_reset_link}
            
            If you have the app installed, use this link: {app_reset_link}
            
            This link will expire in 24 hours.
            If you didn't request this, please ignore this email.
            """,
            html_body=html_body
        )
        
        return jsonify({
            "success": True,
            "message": "If an account exists with this email, a password reset link has been sent."
        }), 200
        
    except Exception as e:
        print(f"Forgot password error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/auth/reset-password', methods=['POST'])
def reset_password():
    try:
        data = request.get_json()
        
        if not data or 'token' not in data or 'new_password' not in data:
            return jsonify({"error": "Token and new password required"}), 400
        
        # Verify token
        conn = sqlite3.connect(Config.DATABASE_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT email, expires_at FROM password_reset_tokens 
            WHERE token = ? AND used = 0
        ''', (data['token'],))
        
        result = cursor.fetchone()
        conn.close()
        
        if not result:
            return jsonify({"error": "Invalid or expired token"}), 400
        
        if datetime.now() > datetime.fromisoformat(result['expires_at']):
            return jsonify({"error": "Token has expired"}), 400
        
        # Update password
        patient = Patient.query.filter_by(email=result['email']).first()
        if not patient:
            return jsonify({"error": "User not found"}), 404
        
        patient.password_hash = hash_password(data['new_password'])
        db.session.commit()
        
        # Mark token as used
        conn = sqlite3.connect(Config.DATABASE_PATH)
        cursor = conn.cursor()
        cursor.execute('UPDATE password_reset_tokens SET used = 1 WHERE token = ?', (data['token'],))
        conn.commit()
        conn.close()
        
        return jsonify({
            "success": True,
            "message": "Password reset successfully"
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@app.route('/api/appointments', methods=['GET'])
@token_required
def get_appointments():
    if g.user_role == 'patient':
        appointments = Appointment.query.filter_by(patient_id=g.user_id).order_by(Appointment.appointment_date.desc()).all()
    else:
        appointments = Appointment.query.filter_by(doctor_id=g.user_id).order_by(Appointment.appointment_date.desc()).all()
    
    result = []
    for apt in appointments:
        result.append({
            "id": apt.id,
            "patient_id": apt.patient_id,
            "doctor_id": apt.doctor_id,
            "appointment_date": apt.appointment_date.isoformat() if apt.appointment_date else None,
            "status": apt.status,
            "consultation_type": apt.consultation_type,
            "is_telemedicine": apt.is_telemedicine,
            "telemedicine_room_id": apt.telemedicine_room_id,
            "symptoms": apt.symptoms,
            "diagnosis": apt.diagnosis,
            "notes": apt.notes,
            "consultation_fee": apt.consultation_fee,
            "doctor_name": f"Dr. {apt.doctor.first_name} {apt.doctor.last_name}" if apt.doctor else "Unknown",
            "doctor_specialty": apt.doctor.specialty if apt.doctor else None,
            "doctor_hospital": apt.doctor.hospital_affiliation if apt.doctor else None,
        })
    return jsonify({"success": True, "appointments": result}), 200

@app.route('/api/appointments', methods=['POST'])
@token_required
def create_appointment():
    try:
        data = request.get_json()
        if g.user_role != 'patient':
            return jsonify({"error": "Only patients can create appointments"}), 403
        
        doctor = db.session.get(Doctor, data['doctor_id'])
        if not doctor:
            return jsonify({"error": "Doctor not found"}), 404
        
        patient = db.session.get(Patient, g.user_id)
        if not patient:
            return jsonify({"error": "Patient not found"}), 404
        
        try:
            appointment_date = datetime.fromisoformat(data['appointment_date'].replace('Z', '+00:00'))
        except ValueError:
            appointment_date = datetime.now() + timedelta(days=1)
        
        is_telemedicine = data.get('is_telemedicine', False)
        room_id = generate_telemedicine_room_id() if is_telemedicine else None
        
        appointment = Appointment(
            patient_id=patient.id,
            doctor_id=doctor.id,
            appointment_date=appointment_date,
            consultation_type=data.get('consultation_type', 'in_person'),
            symptoms=data.get('symptoms'),
            notes=data.get('notes'),
            consultation_fee=doctor.consultation_fee,
            is_telemedicine=is_telemedicine,
            telemedicine_room_id=room_id,
            status='Confirmed',
            is_confirmed=True
        )
        
        db.session.add(appointment)
        db.session.commit()
        
        doctor_name = f"Dr. {doctor.first_name} {doctor.last_name}"
        
        create_notification(
            user_id=doctor.id,
            user_role='doctor',
            title='New Appointment',
            message=f"Appointment booked with {patient.first_name} {patient.last_name}",
            type='appointment'
        )
        
        create_notification(
            user_id=patient.id,
            user_role='patient',
            title='Appointment Confirmed 🏥',
            message=f"Your appointment with {doctor_name} is confirmed." + (f" Room ID: {room_id}" if room_id else ""),
            type='appointment'
        )
        
        return jsonify({
            "success": True,
            "message": "Appointment created successfully",
            "telemedicine_room_id": room_id,
            "appointment": {
                "id": appointment.id,
                "status": appointment.status,
                "telemedicine_room_id": room_id
            }
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/appointments/<int:appointment_id>/cancel', methods=['PUT'])
@token_required
def cancel_appointment(appointment_id):
    try:
        appointment = db.session.get(Appointment, appointment_id)
        if not appointment:
            return jsonify({"success": False, "error": "Appointment not found"}), 404
        
        if g.user_role == 'patient' and appointment.patient_id != g.user_id:
            return jsonify({"success": False, "error": "Unauthorized"}), 403
        elif g.user_role == 'doctor' and appointment.doctor_id != g.user_id:
            return jsonify({"success": False, "error": "Unauthorized"}), 403
        
        appointment.status = 'Cancelled'
        db.session.commit()
        
        doctor_name = f"Dr. {appointment.doctor.first_name} {appointment.doctor.last_name}" if appointment.doctor else "Doctor"
        patient_name = f"{appointment.patient.first_name} {appointment.patient.last_name}" if appointment.patient else "Patient"
        
        create_notification(
            user_id=appointment.doctor_id,
            user_role='doctor',
            title='Appointment Cancelled',
            message=f"Appointment #{appointment.id} was cancelled by patient {patient_name}.",
            type='appointment'
        )
        
        create_notification(
            user_id=appointment.patient_id,
            user_role='patient',
            title='Appointment Cancelled',
            message=f"Your appointment with {doctor_name} has been cancelled.",
            type='appointment'
        )
        
        return jsonify({"success": True, "message": "Appointment cancelled successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/notifications', methods=['GET'])
@token_required
def get_notifications():
    notifications = Notification.query.filter_by(user_id=g.user_id, user_role=g.user_role).order_by(Notification.created_at.desc()).all()
    result = []
    for n in notifications:
        result.append({
            "id": n.id,
            "title": n.title,
            "message": n.message,
            "type": n.type,
            "is_read": 1 if n.is_read else 0,
            "created_at": n.created_at.isoformat()
        })
    return jsonify({"success": True, "notifications": result}), 200

@app.route('/api/notifications/<int:notification_id>/read', methods=['PUT'])
@token_required
def mark_notification_read(notification_id):
    notif = db.session.get(Notification, notification_id)
    if notif and notif.user_id == g.user_id:
        notif.is_read = True
        db.session.commit()
        return jsonify({"success": True}), 200
    return jsonify({"error": "Not found"}), 404

@app.route('/api/notifications/read-all', methods=['PUT'])
@token_required
def mark_all_notifications_read():
    Notification.query.filter_by(user_id=g.user_id, user_role=g.user_role, is_read=False).update({"is_read": True})
    db.session.commit()
    return jsonify({"success": True}), 200

@app.route('/api/notifications/count', methods=['GET'])
@token_required
def get_unread_count():
    count = Notification.query.filter_by(user_id=g.user_id, user_role=g.user_role, is_read=False).count()
    return jsonify({"success": True, "unread_count": count}), 200

@app.route('/api/medical-records', methods=['GET'])
@token_required
def get_medical_records():
    if g.user_role != 'patient':
        return jsonify({"error": "Unauthorized"}), 403
    records = MedicalRecord.query.filter_by(patient_id=g.user_id).order_by(MedicalRecord.record_date.desc()).all()
    result = []
    for r in records:
        file_size_mb = f"{(r.file_size or 1048576) / 1048576:.1f} MB"
        result.append({
            "id": r.id,
            "record_type": r.record_type,
            "title": r.title,
            "description": r.description,
            "record_date": r.record_date.isoformat() if r.record_date else None,
            "department": r.department or 'N/A',
            "attending_physician": r.attending_physician or 'N/A',
            "diagnosis_code": r.diagnosis_code or 'N/A',
            "icd10_code": r.icd10_code or 'N/A',
            "lab_results": r.lab_results or 'N/A',
            "vitals": r.vitals or 'N/A',
            "medications": r.medications or 'N/A',
            "allergies": r.allergies or 'N/A',
            "notes": r.notes or 'N/A',
            "file_name": r.file_name,
            "file_size": file_size_mb,
            "mime_type": r.mime_type,
            "download_url": f"/api/v1/medical-records/{r.id}/download"
        })
    return jsonify({"success": True, "data": result}), 200

@app.route('/api/v1/medical-records/<int:record_id>/download', methods=['GET'], strict_slashes=False)
def download_medical_record(record_id):
    try:
        record = MedicalRecord.query.filter_by(id=record_id).first()
        if not record:
            return jsonify({"error": "Record not found"}), 404
        
        pdf_buffer = generate_professional_pdf(
            record_id=record.id,
            title=record.title,
            description=record.description or 'N/A',
            patient_id=record.patient_id,
            record_type=record.record_type,
            record_date=record.record_date.strftime('%Y-%m-%d') if record.record_date else 'N/A',
            department=record.department or 'N/A',
            attending_physician=record.attending_physician or 'N/A',
            diagnosis_code=record.diagnosis_code or 'N/A',
            icd10_code=record.icd10_code or 'N/A',
            lab_results=record.lab_results or 'N/A',
            vitals=record.vitals or 'N/A',
            medications=record.medications or 'N/A',
            allergies=record.allergies or 'N/A',
            notes=record.notes or 'N/A'
        )
        
        filename = f"{record.title.replace(' ', '_')}_{record.id}.pdf"
        return send_file(
            pdf_buffer,
            mimetype='application/pdf',
            as_attachment=True,
            download_name=filename
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ========== INITIALIZATION ==========
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        init_db()
    print("=" * 50)
    print("Smart Patient Backend - Flask Version")
    print("=" * 50)
    print("Sample Credentials:")
    print("  Patient: patient@example.com / Patient123!")
    print("  Admin: admin@smartmedicalhub.com / Admin123!")
    print("  Admin Panel: http://localhost:8000/admin")
    print("=" * 50)
    app.run(host='0.0.0.0', port=8000, debug=True)