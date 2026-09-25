import sqlite3
from datetime import datetime

def add_immunization():
    conn = sqlite3.connect('smart_patient.db')
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    # 1. Find the patient ID for patient@example.com
    cursor.execute("SELECT id FROM patients WHERE email = 'patient@example.com'")
    patient_result = cursor.fetchone()
    
    if not patient_result:
        print("❌ Patient 'patient@example.com' not found in the database!")
        conn.close()
        return
        
    patient_id = patient_result['id']
    print(f"✅ Found Patient ID: {patient_id}")
    
    # 2. Define the Immunization record data
    immunization_record = {
        'record_type': 'Immunization',
        'title': 'COVID-19 Vaccination (Booster Dose)',
        'description': 'Administered Pfizer-BioNTech COVID-19 mRNA booster vaccine.',
        'file_name': 'covid_booster_cert.pdf',
        'file_size': 1250000, # Approx 1.2 MB
        'mime_type': 'application/pdf',
        'record_date': datetime.now().date().isoformat(),
        'department': 'Immunization & Public Health',
        'attending_physician': 'Dr. Sarah Williams',
        'diagnosis_code': 'Z23',
        'icd10_code': 'Z23',
        'lab_results': 'N/A',
        'vitals': 'BP: 120/80, Temp: 98.4°F, HR: 72 bpm',
        'medications': 'COVID-19 Vaccine Booster (Pfizer)',
        'allergies': 'None known',
        'notes': 'Patient tolerated the vaccination well with no immediate adverse reactions.'
    }
    
    # 3. Insert into medical_records table
    cursor.execute('''
        INSERT INTO medical_records (
            patient_id, record_type, title, description, file_name, file_size, mime_type,
            record_date, department, attending_physician, diagnosis_code, icd10_code,
            lab_results, vitals, medications, allergies, notes
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (
        patient_id,
        immunization_record['record_type'],
        immunization_record['title'],
        immunization_record['description'],
        immunization_record['file_name'],
        immunization_record['file_size'],
        immunization_record['mime_type'],
        immunization_record['record_date'],
        immunization_record['department'],
        immunization_record['attending_physician'],
        immunization_record['diagnosis_code'],
        immunization_record['icd10_code'],
        immunization_record['lab_results'],
        immunization_record['vitals'],
        immunization_record['medications'],
        immunization_record['allergies'],
        immunization_record['notes']
    ))
    
    conn.commit()
    print(f"📄 Successfully added: {immunization_record['record_type']} - {immunization_record['title']}")
    
    conn.close()
    print("✅ Database updated successfully!")

if __name__ == "__main__":
    add_immunization()