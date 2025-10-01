#!/usr/bin/env python3
"""
Test script to verify JWT authentication with your Runaway Coach API
Run this to test if your server is properly configured for JWT tokens
"""

import requests
import json
import sys

# Your API base URL
API_BASE_URL = "https://runaway-coach-api-203308554831.us-central1.run.app"

def test_jwt_token(jwt_token, auth_user_id=None):
    """Test a JWT token against your API"""

    print("🔍 Testing JWT Token Authentication")
    print("=" * 60)

    # Test health endpoint (usually doesn't require auth)
    print("\n1️⃣ Testing Health Endpoint (no auth required):")
    try:
        response = requests.get(f"{API_BASE_URL}/health", timeout=10)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.text[:100]}...")
    except Exception as e:
        print(f"   ❌ Health check failed: {e}")

    # Test protected endpoint with JWT
    print("\n2️⃣ Testing Protected Endpoint with JWT:")
    headers = {
        "Authorization": f"Bearer {jwt_token}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

    # Test data (minimal)
    test_data = [{
        "id": 1,
        "name": "Test Run",
        "distance": 5000.0,
        "elapsed_time": 1800.0,
        "type": "Run"
    }]

    try:
        response = requests.post(
            f"{API_BASE_URL}/analysis/quick-insights",
            headers=headers,
            json=test_data,
            timeout=30
        )

        print(f"   Status: {response.status_code}")

        if response.status_code == 200:
            print("   ✅ JWT Authentication SUCCESS!")
            print(f"   Response: {response.text[:200]}...")
        elif response.status_code == 401:
            print("   ❌ JWT Authentication FAILED (401 Unauthorized)")
            print(f"   Error: {response.text}")

            # Parse error details
            try:
                error_data = response.json()
                if "detail" in error_data:
                    print(f"   Detail: {error_data['detail']}")
            except:
                pass

        else:
            print(f"   ❓ Unexpected status: {response.status_code}")
            print(f"   Response: {response.text}")

    except Exception as e:
        print(f"   ❌ Request failed: {e}")

    # Test with auth_user_id parameter if provided
    if auth_user_id:
        print(f"\n3️⃣ Testing with auth_user_id parameter: {auth_user_id}")
        try:
            response = requests.post(
                f"{API_BASE_URL}/analysis/quick-insights?auth_user_id={auth_user_id}",
                headers=headers,
                json=test_data,
                timeout=30
            )
            print(f"   Status with user ID: {response.status_code}")
            if response.status_code != 200:
                print(f"   Error: {response.text}")
        except Exception as e:
            print(f"   ❌ Request with user ID failed: {e}")

def main():
    print("JWT Token Tester for Runaway Coach API")
    print("=" * 60)

    if len(sys.argv) < 2:
        print("Usage: python test_jwt_server.py <jwt_token> [auth_user_id]")
        print("\nExample:")
        print("python test_jwt_server.py eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
        print("python test_jwt_server.py eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... bab94363-5d47-4118-89a5-73ec3331e1d6")
        return

    jwt_token = sys.argv[1]
    auth_user_id = sys.argv[2] if len(sys.argv) > 2 else None

    test_jwt_token(jwt_token, auth_user_id)

if __name__ == "__main__":
    main()