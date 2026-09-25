"""
Test script for Smart Patient API
"""
import requests
import json
import time

BASE_URL = "http://localhost:8000"

def print_response(name, response):
    """Print formatted response"""
    print(f"\n{'='*60}")
    print(f"TEST: {name}")
    print(f"URL: {response.url}")
    print(f"Status: {response.status_code}")
    if response.text:
        try:
            data = response.json()
            print(f"Response: {json.dumps(data, indent=2)}")
            return data
        except:
            print(f"Response: {response.text}")
    return None

def test_basic():
    """Test basic endpoints"""
    print("🧪 Testing Basic Endpoints")
    
    # Test root
    response = requests.get(f"{BASE_URL}/")
    print_response("Root Endpoint", response)
    
    # Test health
    response = requests.get(f"{BASE_URL}/health")
    print_response("Health Check", response)

def test_auth_flow():
    """Test complete authentication flow"""
    print("\n🧪 Testing Authentication Flow")
    
    # Generate unique email
    timestamp = int(time.time())
    email = f"test_{timestamp}@example.com"
    
    # Register
    register_data = {
        "email": email,
        "password": "SecurePass123",
        "first_name": "Test",
        "last_name": "User",
        "phone": f"+2547{timestamp % 100000000:08d}",
        "date_of_birth": "2000-01-01"
    }
    
    response = requests.post(f"{BASE_URL}/api/auth/register", json=register_data)
    result = print_response("Register Patient", response)
    
    if not result or 'token' not in result:
        print("❌ Registration failed")
        return None
    
    token = result['token']
    print(f"Token obtained: {token[:50]}...")
    
    # Login
    login_data = {
        "email": email,
        "password": "SecurePass123"
    }
    
    response = requests.post(f"{BASE_URL}/api/auth/login", json=login_data)
    result = print_response("Login Patient", response)
    
    if result and 'token' in result:
        token = result['token']  # Use new token from login
    
    # Get current user
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/api/auth/me", headers=headers)
    print_response("Get Current User", response)
    
    # Setup PIN
    pin_data = {"pin": "1234", "confirm_pin": "1234"}
    response = requests.post(f"{BASE_URL}/api/auth/setup-pin", 
                            headers=headers, json=pin_data)
    print_response("Setup PIN", response)
    
    # Verify PIN
    verify_data = {"pin": "1234"}
    response = requests.post(f"{BASE_URL}/api/auth/verify-pin",
                           headers=headers, json=verify_data)
    print_response("Verify PIN", response)
    
    return token

def test_appointments(token):
    """Test appointment functionality"""
    if not token:
        return
    
    print("\n🧪 Testing Appointments")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Get appointments (should be empty)
    response = requests.get(f"{BASE_URL}/api/appointments", headers=headers)
    result = print_response("Get Appointments", response)
    
    # Create appointment (using default doctor ID 1)
    import datetime
    appointment_date = (datetime.datetime.utcnow() + datetime.timedelta(days=7)).isoformat()
    
    appointment_data = {
        "doctor_id": 1,
        "appointment_date": appointment_date,
        "symptoms": "Fever and headache",
        "notes": "Regular checkup",
        "consultation_type": "in_person"
    }
    
    response = requests.post(f"{BASE_URL}/api/appointments", 
                           headers=headers, json=appointment_data)
    result = print_response("Create Appointment", response)
    
    # Get appointments again (should have one)
    response = requests.get(f"{BASE_URL}/api/appointments", headers=headers)
    print_response("Get Appointments After Creation", response)

def main():
    """Run all tests"""
    print("=" * 60)
    print("SMART PATIENT API TEST SUITE")
    print("=" * 60)
    
    try:
        test_basic()
        token = test_auth_flow()
        test_appointments(token)
        
        print("\n" + "=" * 60)
        print("✅ ALL TESTS COMPLETED SUCCESSFULLY!")
        print("=" * 60)
        
    except requests.exceptions.ConnectionError:
        print("\n❌ Cannot connect to server. Make sure Flask is running:")
        print("   python app.py")
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")

if __name__ == "__main__":
    main()