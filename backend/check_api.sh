#!/bin/bash

echo "============================================"
echo "Smart Patient API Health Check"
echo "============================================"

# Health check
echo -e "\n📊 Health Check:"
curl -s http://localhost:8000/health | python -m json.tool

# Get doctors
echo -e "\n👨‍⚕️ Doctors:"
curl -s http://localhost:8000/api/doctors | python -m json.tool | head -30

# Login and get token
echo -e "\n🔐 Logging in as patient..."
RESPONSE=$(curl -s -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"patient@example.com","password":"Patient123!"}')

TOKEN=$(echo $RESPONSE | python -c "import sys, json; print(json.load(sys.stdin).get('token', ''))")

if [ -n "$TOKEN" ]; then
    echo "✅ Token obtained: ${TOKEN:0:20}..."
    
    # Get appointments
    echo -e "\n📋 Appointments:"
    curl -s -X GET http://localhost:8000/api/appointments \
      -H "Authorization: Bearer $TOKEN" \
      | python -m json.tool | head -40
else
    echo "❌ Failed to get token"
    echo "Response: $RESPONSE"
fi

echo -e "\n============================================"
echo "✅ Health check complete!"