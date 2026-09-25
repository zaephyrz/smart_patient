import sqlite3
from datetime import datetime, timedelta
import random
import string
import hashlib

def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

def generate_telemedicine_room_id():
    digits = ''.join(random.choices(string.digits, k=5))
    return f"SMH-{digits}"

def populate_all_data():
    conn = sqlite3.connect('smart_patient.db')
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    # 1. Get or create patient ID
    cursor.execute("SELECT id FROM patients WHERE email = 'patient@example.com'")
    patient_result = cursor.fetchone()
    if not patient_result:
        print("❌ Patient not found! Creating patient...")
        cursor.execute('''
            INSERT INTO patients (
                email, phone, password_hash, first_name, last_name, 
                date_of_birth, gender, blood_group, is_active
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            'patient@example.com',
            '+1234567890',
            hash_password('Patient123!'),
            'John',
            'Doe',
            '1990-01-15',
            'Male',
            'A+',
            1
        ))
        conn.commit()
        patient_id = cursor.lastrowid
        print(f"✅ Created patient with ID: {patient_id}")
    else:
        patient_id = patient_result['id']
        print(f"✅ Patient ID: {patient_id}")
    
    # 2. Ensure all required doctors exist (upsert by email to prevent IndexError)
    placeholder_images = {
        'smith': 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMTAwIiB2aWV3Qm94PSIwIDAgMTAwIDEwMCI+PHJlY3Qgd2lkdGg9IjEwMCIgaGVpZ2h0PSIxMDAiIGZpbGw9IiM0QTYwQzkiLz48dGV4dCB4PSI1MCIgeT0iNTUiIGZvbnQtc2l6ZT0iNDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZmlsbD0id2hpdGUiPkpTPC90ZXh0Pjwvc3ZnPg==',
        'johnson': 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMTAwIiB2aWV3Qm94PSIwIDAgMTAwIDEwMCI+PHJlY3Qgd2lkdGg9IjEwMCIgaGVpZ2h0PSIxMDAiIGZpbGw9IiMyN0FFNjMoLz48dGV4dCB4PSI1MCIgeT0iNTUiIGZvbnQtc2l6ZT0iNDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZmlsbD0id2hpdGUiPk1KPC90ZXh0Pjwvc3ZnPg==',
        'williams': 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMTAwIiB2aWV3Qm94PSIwIDAgMTAwIDEwMCI+PHJlY3Qgd2lkdGg9IjEwMCIgaGVpZ2h0PSIxMDAiIGZpbGw9IiM4RTQ0QUQiLz48dGV4dCB4PSI1MCIgeT0iNTUiIGZvbnQtc2l6ZT0iNDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZmlsbD0id2hpdGUiPlNXPC90ZXh0Pjwvc3ZnPg==',
        'brown': 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMTAwIiB2aWV3Qm94PSIwIDAgMTAwIDEwMCI+PHJlY3Qgd2lkdGg9IjEwMCIgaGVpZ2h0PSIxMDAiIGZpbGw9IiNFNjdFMjIiLz48dGV4dCB4PSI1MCIgeT0iNTUiIGZvbnQtc2l6ZT0iNDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZmlsbD0id2hpdGUiPlJCPC90ZXh0Pjwvc3ZnPg=='
    }
    
    doctors_data = [
        {
            'email': 'doctor.smith@hospital.com',
            'phone': '+1234567891',
            'first_name': 'Jane',
            'last_name': 'Smith',
            'specialty': 'Cardiology',
            'license_number': 'LIC-2024-001',
            'hospital_affiliation': 'Smart Medical Heart Center',
            'consultation_fee': 150.00,
            'rating': 4.8,
            'profile_image': placeholder_images['smith']
        },
        {
            'email': 'doctor.johnson@hospital.com',
            'phone': '+1234567892',
            'first_name': 'Michael',
            'last_name': 'Johnson',
            'specialty': 'Neurology',
            'license_number': 'LIC-2024-002',
            'hospital_affiliation': 'Smart Medical Neuro Center',
            'consultation_fee': 200.00,
            'rating': 4.6,
            'profile_image': placeholder_images['johnson']
        },
        {
            'email': 'doctor.williams@hospital.com',
            'phone': '+1234567893',
            'first_name': 'Sarah',
            'last_name': 'Williams',
            'specialty': 'Pediatrics',
            'license_number': 'LIC-2024-003',
            'hospital_affiliation': "Smart Medical Children's Center",
            'consultation_fee': 120.00,
            'rating': 4.9,
            'profile_image': placeholder_images['williams']
        },
        {
            'email': 'doctor.brown@hospital.com',
            'phone': '+1234567894',
            'first_name': 'Robert',
            'last_name': 'Brown',
            'specialty': 'Orthopedics',
            'license_number': 'LIC-2024-004',
            'hospital_affiliation': 'Smart Medical Ortho Center',
            'consultation_fee': 180.00,
            'rating': 4.7,
            'profile_image': placeholder_images['brown']
        }
    ]
    
    for doc_data in doctors_data:
        cursor.execute("SELECT id FROM doctors WHERE email = ?", (doc_data['email'],))
        existing_doc = cursor.fetchone()
        if not existing_doc:
            cursor.execute('''
                INSERT INTO doctors (
                    email, phone, password_hash, first_name, last_name,
                    specialty, license_number, hospital_affiliation,
                    consultation_fee, rating, profile_image, is_active
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                doc_data['email'],
                doc_data['phone'],
                hash_password('Doctor123!'),
                doc_data['first_name'],
                doc_data['last_name'],
                doc_data['specialty'],
                doc_data['license_number'],
                doc_data['hospital_affiliation'],
                doc_data['consultation_fee'],
                doc_data['rating'],
                doc_data['profile_image'],
                1
            ))
    conn.commit()
    print("✅ Verified/Added all 4 required doctors.")
    
    # Fetch all doctors to map correctly
    cursor.execute("SELECT id, first_name, last_name, consultation_fee FROM doctors")
    doctors = cursor.fetchall()
    
    if not doctors:
        print("❌ No doctors found! Something went wrong.")
        conn.close()
        return
    
    # 3. Clear existing appointments for this patient
    cursor.execute("DELETE FROM appointments WHERE patient_id = ?", (patient_id,))
    print("🗑️  Cleared existing appointments")
    
    # Create appointments
    now = datetime.now()
    appointments_added = 0
    
    appointment_data = [
        {
            'days_ago': 90,
            'hour': 11,
            'minute': 30,
            'doctor_index': 0,
            'status': 'Completed',
            'type': 'in_person',
            'symptoms': 'Chest pain and shortness of breath',
            'diagnosis': 'Mild angina, prescribed medication',
            'notes': 'Follow-up in 3 months',
            'fee': 150.00,
            'is_confirmed': True
        },
        {
            'days_ago': 60,
            'hour': 10,
            'minute': 0,
            'doctor_index': 1,
            'status': 'Completed',
            'type': 'in_person',
            'symptoms': 'Frequent headaches and dizziness',
            'diagnosis': 'Migraine with aura, prescribed preventive medication',
            'notes': 'Keep headache diary',
            'fee': 200.00,
            'is_confirmed': True
        },
        {
            'days_ago': 30,
            'hour': 14,
            'minute': 30,
            'doctor_index': 2,
            'status': 'Completed',
            'type': 'in_person',
            'symptoms': "Child's routine checkup",
            'diagnosis': 'Normal development, all vitals good',
            'notes': 'Next appointment in 6 months',
            'fee': 120.00,
            'is_confirmed': True
        },
        {
            'days_ago': 14,
            'hour': 9,
            'minute': 0,
            'doctor_index': 3,
            'status': 'Completed',
            'type': 'in_person',
            'symptoms': 'Knee pain after exercise',
            'diagnosis': 'Mild strain, recommended physical therapy',
            'notes': 'Ice and rest for 2 weeks',
            'fee': 180.00,
            'is_confirmed': True
        },
        {
            'days_ago': 7,
            'hour': 15,
            'minute': 0,
            'doctor_index': 0,
            'status': 'Completed',
            'type': 'telemedicine',
            'symptoms': 'Follow-up on heart medication',
            'diagnosis': 'Blood pressure stable, continue current medication',
            'notes': 'Check BP daily and report',
            'fee': 150.00,
            'is_confirmed': True
        },
        {
            'days_ago': -3,
            'hour': 14,
            'minute': 0,
            'doctor_index': 1,
            'status': 'Confirmed',
            'type': 'in_person',
            'symptoms': 'Follow-up for migraine treatment',
            'diagnosis': None,
            'notes': 'Bring headache diary',
            'fee': 200.00,
            'is_confirmed': True
        },
        {
            'days_ago': -7,
            'hour': 10,
            'minute': 30,
            'doctor_index': 3,
            'status': 'Pending',
            'type': 'in_person',
            'symptoms': 'Physical therapy consultation',
            'diagnosis': None,
            'notes': 'First PT session',
            'fee': 180.00,
            'is_confirmed': False
        },
        {
            'days_ago': -1,
            'hour': 9,
            'minute': 30,
            'doctor_index': 2,
            'status': 'Confirmed',
            'type': 'telemedicine',
            'symptoms': 'Follow-up pediatric consultation',
            'diagnosis': None,
            'notes': 'Video call appointment',
            'fee': 120.00,
            'is_confirmed': True
        }
    ]
    
    for data in appointment_data:
        # Safe modulo indexing prevents IndexError even if doctor count varies
        doc_idx = data['doctor_index'] % len(doctors)
        doctor = doctors[doc_idx]
        doctor_id = doctor['id']
        fee = data.get('fee', doctor['consultation_fee'])
        
        if data['days_ago'] >= 0:
            appointment_date = now - timedelta(days=data['days_ago'])
        else:
            appointment_date = now + timedelta(days=abs(data['days_ago']))
        
        appointment_date = appointment_date.replace(
            hour=data['hour'],
            minute=data['minute'],
            second=0,
            microsecond=0
        )
        
        is_telemedicine = 1 if data['type'] == 'telemedicine' else 0
        telemedicine_room_id = generate_telemedicine_room_id() if is_telemedicine else None
        
        cursor.execute('''
            INSERT INTO appointments (
                patient_id, doctor_id, appointment_date, status,
                consultation_type, symptoms, diagnosis, notes,
                is_telemedicine, telemedicine_room_id, duration_minutes, 
                consultation_fee, is_confirmed
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            patient_id,
            doctor_id,
            appointment_date.isoformat(),
            data['status'],
            data['type'],
            data.get('symptoms', ''),
            data.get('diagnosis'),
            data['notes'],
            is_telemedicine,
            telemedicine_room_id,
            30,
            fee,
            1 if data['is_confirmed'] else 0
        ))
        
        appointments_added += 1
        status_emoji = "✅" if data['status'] == 'Confirmed' else "🟡" if data['status'] == 'Pending' else "📋"
        print(f"  {status_emoji} Added: {appointment_date.strftime('%Y-%m-%d %H:%M')} - {data['status']} - Dr. {doctor['first_name']} {doctor['last_name']}")
    
    conn.commit()
    print(f"✅ Added {appointments_added} appointments.")
    
    # 4. Clear and recreate medical records for this patient
    cursor.execute("DELETE FROM medical_records WHERE patient_id = ?", (patient_id,))
    print("\n🗑️  Cleared existing medical records")
    
    sample_records = [
        {
            'record_type': 'Lab Report',
            'title': 'Complete Blood Count (CBC)',
            'description': 'Comprehensive blood panel analysis showing all values within normal range.',
            'file_name': 'cbc_report.pdf',
            'file_size': 2457600,
            'mime_type': 'application/pdf',
            'record_date': (datetime.now() - timedelta(days=7)).date(),
            'department': 'Hematology',
            'attending_physician': 'Dr. Jane Smith',
            'diagnosis_code': 'D50.9',
            'icd10_code': 'D50.9',
            'lab_results': 'WBC: 7.5 (4.5-11.0), RBC: 5.2 (4.7-6.1), Hemoglobin: 15.2 (13.5-17.5), Platelets: 250 (150-400)',
            'vitals': 'BP: 118/72, HR: 72, Temp: 98.6°F, Resp: 16',
            'medications': 'None',
            'allergies': 'None known',
            'notes': 'Patient is in good health. All values within normal limits.'
        },
        {
            'record_type': 'Prescription',
            'title': 'Amoxicillin 500mg',
            'description': 'Antibiotic prescription for bacterial infection. Take 3 times daily for 7 days.',
            'file_name': 'prescription_amoxicillin.pdf',
            'file_size': 835584,
            'mime_type': 'application/pdf',
            'record_date': (datetime.now() - timedelta(days=14)).date(),
            'department': 'Internal Medicine',
            'attending_physician': 'Dr. Michael Johnson',
            'diagnosis_code': 'J06.9',
            'icd10_code': 'J06.9',
            'lab_results': 'N/A',
            'vitals': 'BP: 120/78, HR: 76, Temp: 100.2°F, Resp: 18',
            'medications': 'Amoxicillin 500mg - 3 times daily for 7 days',
            'allergies': 'None known',
            'notes': 'Prescribed for upper respiratory infection.'
        },
        {
            'record_type': 'X-Ray',
            'title': 'Chest X-Ray Report',
            'description': 'Full chest imaging for respiratory evaluation. No abnormalities detected.',
            'file_name': 'chest_xray.jpg',
            'file_size': 15600000,
            'mime_type': 'image/jpeg',
            'record_date': (datetime.now() - timedelta(days=60)).date(),
            'department': 'Radiology',
            'attending_physician': 'Dr. Sarah Williams',
            'diagnosis_code': 'R91.8',
            'icd10_code': 'R91.8',
            'lab_results': 'N/A',
            'vitals': 'BP: 116/70, HR: 68, Temp: 98.4°F, Resp: 14',
            'medications': 'None',
            'allergies': 'None known',
            'notes': 'Normal chest X-ray. No abnormalities detected.'
        },
        {
            'record_type': 'Receipt',
            'title': 'Consultation Fee - Cardiology',
            'description': 'Payment for cardiology consultation with Dr. Smith.',
            'file_name': 'receipt_001.pdf',
            'file_size': 512000,
            'mime_type': 'application/pdf',
            'record_date': (datetime.now() - timedelta(days=7)).date(),
            'department': 'Cardiology',
            'attending_physician': 'Dr. Jane Smith',
            'diagnosis_code': 'N/A',
            'icd10_code': 'N/A',
            'lab_results': 'N/A',
            'vitals': 'N/A',
            'medications': 'N/A',
            'allergies': 'N/A',
            'notes': 'Payment processed for consultation'
        }
    ]
    
    records_added = 0
    for record_data in sample_records:
        cursor.execute('''
            INSERT INTO medical_records (
                patient_id, record_type, title, description, file_name, file_size, mime_type,
                record_date, department, attending_physician, diagnosis_code, icd10_code,
                lab_results, vitals, medications, allergies, notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            patient_id,
            record_data['record_type'],
            record_data['title'],
            record_data['description'],
            record_data['file_name'],
            record_data['file_size'],
            record_data['mime_type'],
            record_data['record_date'].isoformat(),
            record_data['department'],
            record_data['attending_physician'],
            record_data['diagnosis_code'],
            record_data['icd10_code'],
            record_data['lab_results'],
            record_data['vitals'],
            record_data['medications'],
            record_data['allergies'],
            record_data['notes']
        ))
        records_added += 1
        print(f"  📄 Added: {record_data['record_type']} - {record_data['title']}")
    
    conn.commit()
    
    # 5. Summary validation
    cursor.execute("SELECT COUNT(*) as count FROM patients")
    patient_count = cursor.fetchone()['count']
    cursor.execute("SELECT COUNT(*) as count FROM doctors")
    doctor_count = cursor.fetchone()['count']
    cursor.execute("SELECT COUNT(*) as count FROM appointments WHERE patient_id = ?", (patient_id,))
    appointment_count = cursor.fetchone()['count']
    cursor.execute("SELECT COUNT(*) as count FROM medical_records WHERE patient_id = ?", (patient_id,))
    record_count = cursor.fetchone()['count']
    
    print("\n" + "=" * 50)
    print("📊 DATABASE SUMMARY:")
    print(f"  Patients: {patient_count}")
    print(f"  Doctors: {doctor_count}")
    print(f"  Appointments: {appointment_count}")
    print(f"  Medical Records: {record_count}")
    print("=" * 50)
    
    conn.close()
    print("\n✅ All data populated successfully!")

if __name__ == "__main__":
    populate_all_data()