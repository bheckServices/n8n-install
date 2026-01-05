# PostgreSQL Remote Access - Quick Start Guide

Fast setup guide for accessing your PostgreSQL database remotely via Cloudflare Tunnel.

## Quick Setup (5 Steps)

### 1️⃣ Configure Cloudflare Tunnel

**Option A: Via Dashboard (Easiest)**
1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) → Networks → Tunnels
2. Select your tunnel → Public Hostname → Add public hostname
3. Configure:
   - **Subdomain:** `postgres`
   - **Domain:** `yourdomain.com`
   - **Type:** `TCP`
   - **URL:** `postgres:5432`

**Option B: Via config.yml**
Add to your tunnel config:
```yaml
ingress:
  - hostname: postgres.yourdomain.com
    service: tcp://postgres:5432
  # ... other services ...
  - service: http_status:404
```

### 2️⃣ Create Remote Access User

```bash
# Access PostgreSQL container
docker exec -it n8nInstall_postgres psql -U postgres

# Create user (replace password!)
CREATE USER remote_user WITH PASSWORD 'CHANGE_THIS_TO_STRONG_PASSWORD';

# Grant access to databases
GRANT CONNECT ON DATABASE postgres TO remote_user;
GRANT CONNECT ON DATABASE n8n TO remote_user;
GRANT CONNECT ON DATABASE langfuse TO remote_user;

# Grant privileges on postgres database
GRANT USAGE ON SCHEMA public TO remote_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO remote_user;
GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO remote_user;

# Grant privileges on n8n database
\c n8n
GRANT USAGE ON SCHEMA public TO remote_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO remote_user;
GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO remote_user;

# Grant privileges on langfuse database
\c langfuse
GRANT USAGE ON SCHEMA public TO remote_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO remote_user;
GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO remote_user;

\q
```

**Or use automated script:**
```bash
# Edit password in postgres/02_create_remote_user.sql first
docker exec -i n8nInstall_postgres psql -U postgres < postgres/02_create_remote_user.sql
```

### 3️⃣ Verify Tunnel is Running

```bash
docker logs n8nInstall_cloudflared --tail 30
```

Look for: `Connection established` or `Registered tunnel connection`

### 4️⃣ Connect from DataGrip

1. **New Data Source** → PostgreSQL
2. **Connection Details:**
   - Host: `postgres.yourdomain.com`
   - Port: `5432`
   - Database: `postgres` (or `n8n`, `langfuse`)
   - User: `remote_user`
   - Password: `your_password`
   - SSL: `prefer` ✓

3. **Test Connection** → **OK**

### 5️⃣ Connect from n8n

**Postgres Node Credentials:**
- Host: `postgres.yourdomain.com`
- Port: `5432`
- Database: `postgres`
- User: `remote_user`
- Password: `your_password`
- SSL: Enabled ✓

**Connection String:**
```
postgresql://remote_user:your_password@postgres.yourdomain.com:5432/postgres?sslmode=prefer
```

## Test Connection

### From Command Line (psql):
```bash
psql "postgresql://remote_user:your_password@postgres.yourdomain.com:5432/postgres?sslmode=prefer"
```

### From DataGrip:
```sql
SELECT version();
SELECT current_database();
\dt  -- List tables
```

### From n8n:
Create a workflow with Postgres node and run:
```sql
SELECT current_database(), current_user, version();
```

## Common Issues

### ❌ Connection Refused
**Fix:** Check tunnel status
```bash
docker logs n8nInstall_cloudflared --tail 50
docker ps | grep cloudflared
```

### ❌ Authentication Failed
**Fix:** Verify user exists
```bash
docker exec -it n8nInstall_postgres psql -U postgres -c "\du"
```

### ❌ SSL/TLS Error
**Fix:** Try different SSL modes: `disable`, `prefer`, `require`

### ❌ DNS Not Resolving
**Fix:** Check DNS records
```bash
nslookg postgres.yourdomain.com
```

## Security Checklist

- ✅ Strong password (minimum 32 characters)
- ✅ Dedicated user (not `postgres` superuser)
- ✅ SSL/TLS enabled
- ✅ Minimal privileges granted
- ✅ Cloudflare Tunnel (not direct port exposure)
- ✅ Regular password rotation

## Available Databases

| Database | Purpose | Default Tables |
|----------|---------|----------------|
| `postgres` | Default DB, used by Postiz, WAHA, LightRAG | Varies by service |
| `n8n` | n8n workflow automation | workflows, credentials, executions |
| `langfuse` | Langfuse observability | traces, observations, projects |

## Connection String Template

```bash
# General format
postgresql://[user]:[password]@[host]:[port]/[database]?sslmode=[mode]

# Example
postgresql://remote_user:mypassword@postgres.yourdomain.com:5432/n8n?sslmode=prefer

# Read-only connection (if read-only user created)
postgresql://readonly_user:mypassword@postgres.yourdomain.com:5432/postgres?sslmode=require
```

## Next Steps

📖 **Full Documentation:** See [CLOUDFLARE_TUNNEL_POSTGRES.md](CLOUDFLARE_TUNNEL_POSTGRES.md)

🔐 **Create Read-Only User:**
```sql
CREATE USER readonly_user WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE postgres TO readonly_user;
\c postgres
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
```

🛡️ **Add Cloudflare Access (Extra Security):**
1. Zero Trust Dashboard → Access → Applications
2. Add application for `postgres.yourdomain.com`
3. Configure authentication (email, SSO, etc.)

---

**Need Help?**
- Check logs: `docker logs n8nInstall_postgres`
- Check tunnel: `docker logs n8nInstall_cloudflared`
- Full guide: [CLOUDFLARE_TUNNEL_POSTGRES.md](CLOUDFLARE_TUNNEL_POSTGRES.md)
