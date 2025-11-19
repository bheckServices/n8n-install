#!/bin/bash
# Supabase JWT Key Generator
# Usage: ./generate_supabase_keys.sh YOUR_JWT_SECRET

if [ -z "$1" ]; then
  echo "Usage: $0 <JWT_SECRET>"
  exit 1
fi

JWT_SECRET="$1"

echo "Generating Supabase keys..."
echo ""
echo "JWT_SECRET: $JWT_SECRET"
echo ""

# Generate anon key (expires in 10 years)
ANON_KEY=$(docker run --rm supabase/gotrue:latest sh -c "
cat > /tmp/payload.json <<'PAYLOAD'
{
  \"role\": \"anon\",
  \"iss\": \"supabase\",
  \"iat\": $(date +%s),
  \"exp\": $(date -d '+10 years' +%s)
}
PAYLOAD
JWT_SECRET='$JWT_SECRET' /usr/local/bin/gotrue token -payload /tmp/payload.json
")

# Generate service_role key (expires in 10 years)
SERVICE_ROLE_KEY=$(docker run --rm supabase/gotrue:latest sh -c "
cat > /tmp/payload.json <<'PAYLOAD'
{
  \"role\": \"service_role\",
  \"iss\": \"supabase\",
  \"iat\": $(date +%s),
  \"exp\": $(date -d '+10 years' +%s)
}
PAYLOAD
JWT_SECRET='$JWT_SECRET' /usr/local/bin/gotrue token -payload /tmp/payload.json
")

echo "ANON_KEY: $ANON_KEY"
echo ""
echo "SERVICE_ROLE_KEY: $SERVICE_ROLE_KEY"

