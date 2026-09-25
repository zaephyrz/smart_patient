import requests
import json

BASE_URL = "http://localhost:8000"

def test_endpoint(name, method, endpoint, data=None, token=None):
    print(f"\n{'='*50}")
    print(f"Testing: {name}")
    print(f"{'='*50}")
    
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    
    url = f"{BASE_URL}{endpoint}"
    
    try:
        if method == "GET":
            response = requests.get(url, headers=headers)
        elif method == "POST":
            response = requests.post(url, headers=headers, json=data)
        
        print(f"Status: {response.status_code}")
        if response.text:
            print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        return response.json() if response.text else None
    except Exception as e:
        print(f"Error: {e}")
        return None

def main():
    print("🧪 Testing Smart Patient Backend")
    
    # Test 1: Basic endpoints
    test_endpoint("Root", "GET", "/")
    test_endpoint("Health", "GET", "/health")
    
    # Test 2: Register
    register_data = {
        "email": f"test_{hash(str(hash))[:8]}@example.com",
        "password": "TestPass123",
        "first_name": "Test",
        "last_name": "User",
        "phone": "+254700000001",
        "date_of_birth": "2000-01-01"
    }
    
    register_response = test_endpoint("Register", "POST", "/api/auth/register", register_data)
    
    if register_response and 'token' in register_response:
        token = register_response['token']
        
        # Test 3: Login
        login_data = {
            "email": register_data["email"],
            "password": register_data["password"]
        }
        test_endpoint("Login", "POST", "/api/auth/login", login_data)
        
        # Test 4: Get current user
        test_endpoint("Get Current User", "GET", "/api/auth/me", token=token)
        
        # Test 5: Setup PIN
        pin_data = {"pin": "1234", "confirm_pin": "1234"}
        test_endpoint("Setup PIN", "POST", "/api/auth/setup-pin", pin_data, token=token)
    
    print("\n✅ All tests completed!")

if __name__ == "__main__":
    main()