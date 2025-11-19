#!/usr/bin/env python3
"""
Supabase JWT Key Generator
Generates anon and service_role keys from a JWT secret
"""

import jwt
import time
import sys

def generate_supabase_keys(jwt_secret):
    """Generate Supabase anon and service_role keys"""

    current_time = int(time.time())
    expiry_time = current_time + (10 * 365 * 24 * 60 * 60)  # 10 years

    # Generate anon key
    anon_payload = {
        "role": "anon",
        "iss": "supabase",
        "iat": current_time,
        "exp": expiry_time
    }
    anon_key = jwt.encode(anon_payload, jwt_secret, algorithm="HS256")

    # Generate service_role key
    service_role_payload = {
        "role": "service_role",
        "iss": "supabase",
        "iat": current_time,
        "exp": expiry_time
    }
    service_role_key = jwt.encode(service_role_payload, jwt_secret, algorithm="HS256")

    return anon_key, service_role_key

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python generate_supabase_keys.py <JWT_SECRET>")
        print("\nExample: python generate_supabase_keys.py your-super-secret-jwt-token-with-at-least-32-characters-long")
        sys.exit(1)

    jwt_secret = sys.argv[1]

    if len(jwt_secret) < 32:
        print("ERROR: JWT_SECRET should be at least 32 characters long for security")
        sys.exit(1)

    print("Generating Supabase keys...")
    print("=" * 80)
    print()

    try:
        anon_key, service_role_key = generate_supabase_keys(jwt_secret)

        print("JWT_SECRET:")
        print(jwt_secret)
        print()
        print("ANON_KEY (for Lovable):")
        print(anon_key)
        print()
        print("SERVICE_ROLE_KEY (keep secret!):")
        print(service_role_key)
        print()
        print("=" * 80)
        print("✓ Keys generated successfully!")
        print("\nFor Lovable, use the ANON_KEY above.")

    except Exception as e:
        print(f"ERROR: Failed to generate keys: {e}")
        sys.exit(1)
