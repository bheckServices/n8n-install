# PostgreSQL Remote Access via Cloudflare Tunnel

This guide explains how to securely access your PostgreSQL database remotely using Cloudflare Tunnel for both **DataGrip** and **n8n** connections.

## Architecture Overview

```
DataGrip/n8n (Remote)
    ↓ (TLS encrypted)
Cloudflare Network
    ↓ (Cloudflare Tunnel)
VPS Server (postgres:5432 via Docker network)
```

## Prerequisites

1. **Cloudflare account** with a domain added
2. **Cloudflare Tunnel** created (you should have a `tunnel.json` file)
3. **n8n-install** setup running on your VPS

## Step 1: Configure Cloudflare Tunnel for PostgreSQL TCP Access

Cloudflare Tunnel supports **both HTTP and TCP** traffic. For PostgreSQL, you need to configure a **TCP tunnel**.

### Option A: Configure via Cloudflare Dashboard (Recommended)

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Networks** → **Tunnels**
3. Select your existing tunnel
4. Click **Public Hostname** tab
5. Click **Add a public hostname**

**Configuration:**
- **Subdomain:** `postgres` (or any name you prefer)
- **Domain:** `yourdomain.com`
- **Type:** `TCP`
- **URL:** `postgres:5432` (this is the Docker container name and port)

This will create a public hostname like: `postgres.yourdomain.com`

### Option B: Configure via `config.yml` (Advanced)

If you're managing your tunnel via configuration file, add this to your Cloudflare Tunnel `config.yml`:

```yaml
tunnel: <your-tunnel-id>
credentials-file: /etc/cloudflared/tunnel.json

ingress:
  # PostgreSQL TCP tunnel
  - hostname: postgres.yourdomain.com
    service: tcp://postgres:5432

  # Your existing HTTP services
  - hostname: n8n.yourdomain.com
    service: http://caddy:80

  - hostname: flowise.yourdomain.com
    service: http://caddy:80

  # Catch-all rule (required)
  - service: http_status:404
```

**Important:** Make sure the tunnel container can resolve the `postgres` hostname. Since you're using Docker Compose with the same network (`n8nInstall_network`), this should work automatically.

## Step 2: Set Up PostgreSQL Remote User

For security, **DO NOT use the `postgres` superuser** for remote connections. Create a dedicated user:

### Manual Method (Run inside PostgreSQL container):

```bash
# Access the PostgreSQL container
docker exec -it n8nInstall_postgres psql -U postgres

# Create remote user with a strong password
CREATE USER remote_user WITH PASSWORD 'your_very_secure_password_here';

# Grant database access
GRANT CONNECT ON DATABASE postgres TO remote_user;
GRANT CONNECT ON DATABASE n8n TO remote_user;
GRANT CONNECT ON DATABASE langfuse TO remote_user;

# Grant table privileges (for postgres database)
GRANT USAGE ON SCHEMA public TO remote_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO remote_user;
GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO remote_user;

# For n8n database
\c n8n
GRANT USAGE ON SCHEMA public TO remote_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO remote_user;
GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO remote_user;

# For langfuse database
\c langfuse
GRANT USAGE ON SCHEMA public TO remote_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO remote_user;
GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO remote_user;

# Exit
\q
```

### Automated Method (Using SQL Script):

1. Edit the password in `postgres/02_create_remote_user.sql`
2. Run the script:

```bash
docker exec -i n8nInstall_postgres psql -U postgres < postgres/02_create_remote_user.sql
```

## Step 3: Configure PostgreSQL for Remote Connections

PostgreSQL is already configured to accept connections from within the Docker network. No additional `pg_hba.conf` changes needed since traffic comes through the tunnel.

## Step 4: Connect from DataGrip

### Connection Settings:

1. Open **DataGrip**
2. Click **New** → **Data Source** → **PostgreSQL**
3. Configure the connection:

**General Tab:**
- **Host:** `postgres.yourdomain.com`
- **Port:** `5432`
- **Database:** `postgres` (or `n8n`, `langfuse`)
- **User:** `remote_user`
- **Password:** `your_very_secure_password_here`

**SSH/SSL Tab:**
- **Use SSL:** Check this box
- **SSL Mode:** `prefer` or `require` (Cloudflare provides TLS encryption)

4. Click **Test Connection**
5. Click **OK** to save

### Multiple Databases:

You can create separate connections for each database:
- `postgres.yourdomain.com:5432/postgres`
- `postgres.yourdomain.com:5432/n8n`
- `postgres.yourdomain.com:5432/langfuse`

## Step 5: Connect from n8n

You can use the **Postgres** node in n8n workflows to connect remotely.

### n8n Postgres Node Configuration:

1. In your n8n workflow, add a **Postgres** node
2. Create new credentials:

**Credentials:**
- **Host:** `postgres.yourdomain.com`
- **Port:** `5432`
- **Database:** `postgres` (or your target database)
- **User:** `remote_user`
- **Password:** `your_very_secure_password_here`
- **SSL:** Enable SSL (recommended)

**Connection String (Alternative):**
```
postgresql://remote_user:your_very_secure_password_here@postgres.yourdomain.com:5432/postgres?sslmode=prefer
```

### Example n8n Workflow:

```json
{
  "nodes": [
    {
      "name": "Postgres",
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "executeQuery",
        "query": "SELECT * FROM users LIMIT 10"
      },
      "credentials": {
        "postgres": {
          "id": "your-credential-id",
          "name": "Remote Postgres"
        }
      }
    }
  ]
}
```

## Security Best Practices

### 1. **Use Strong Passwords**
Generate secure passwords:
```bash
openssl rand -base64 32
```

### 2. **Limit User Privileges**
Only grant necessary permissions. For read-only access:
```sql
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
```

### 3. **Enable SSL/TLS**
Always use SSL connections. Cloudflare Tunnel automatically encrypts traffic between client and Cloudflare edge.

### 4. **Use Cloudflare Access (Optional)**
Add an extra authentication layer:
1. Go to **Access** → **Applications**
2. Create a new application for `postgres.yourdomain.com`
3. Add authentication policies (email, SSO, etc.)

### 5. **Monitor Connections**
Check active connections:
```sql
SELECT * FROM pg_stat_activity WHERE datname = 'postgres';
```

### 6. **Regular Password Rotation**
Change passwords periodically:
```sql
ALTER USER remote_user WITH PASSWORD 'new_secure_password';
```

## Troubleshooting

### Connection Refused

**Check tunnel status:**
```bash
docker logs n8nInstall_cloudflared --tail 50
```

Look for: `Connection established` or `Registered tunnel connection`

**Check PostgreSQL is running:**
```bash
docker ps | grep postgres
docker logs n8nInstall_postgres --tail 20
```

### Authentication Failed

**Verify user exists:**
```bash
docker exec -it n8nInstall_postgres psql -U postgres -c "\du"
```

**Test local connection:**
```bash
docker exec -it n8nInstall_postgres psql -U remote_user -d postgres
```

### SSL/TLS Issues

**Check PostgreSQL SSL settings:**
```bash
docker exec -it n8nInstall_postgres psql -U postgres -c "SHOW ssl;"
```

If SSL is `off`, you can enable it by adding to `docker-compose.yml`:
```yaml
postgres:
  command: postgres -c ssl=on
```

### DNS Resolution Issues

**Test DNS from your machine:**
```bash
nslookup postgres.yourdomain.com
```

Should resolve to Cloudflare IPs.

### Network Connectivity Test

**Test port connectivity:**
```bash
# Linux/Mac
nc -zv postgres.yourdomain.com 5432

# Windows (PowerShell)
Test-NetConnection -ComputerName postgres.yourdomain.com -Port 5432
```

## Alternative: Direct Port Exposure (Less Secure)

If you don't want to use Cloudflare Tunnel, you can expose PostgreSQL directly:

### docker-compose.yml:
```yaml
postgres:
  ports:
    - "5432:5432"  # WARNING: Exposes to public internet!
```

**Then configure firewall rules:**
```bash
# Allow only your IP
sudo ufw allow from YOUR_IP_ADDRESS to any port 5432
```

⚠️ **Not recommended** for production! Use Cloudflare Tunnel or VPN instead.

## Connection String Examples

### DataGrip / psql:
```
postgresql://remote_user:password@postgres.yourdomain.com:5432/postgres?sslmode=prefer
```

### n8n Postgres Node:
```
Host: postgres.yourdomain.com
Port: 5432
Database: postgres
User: remote_user
Password: ********
SSL: Enabled
```

### Python (psycopg2):
```python
import psycopg2

conn = psycopg2.connect(
    host="postgres.yourdomain.com",
    port=5432,
    database="postgres",
    user="remote_user",
    password="your_password",
    sslmode="prefer"
)
```

### Node.js (pg):
```javascript
const { Client } = require('pg');

const client = new Client({
  host: 'postgres.yourdomain.com',
  port: 5432,
  database: 'postgres',
  user: 'remote_user',
  password: 'your_password',
  ssl: { rejectUnauthorized: false }
});

await client.connect();
```

## Summary

✅ **Secure:** All traffic encrypted via Cloudflare Tunnel
✅ **No port exposure:** PostgreSQL not directly accessible from internet
✅ **Dedicated user:** Separate credentials for remote access
✅ **DataGrip compatible:** Standard PostgreSQL connection
✅ **n8n compatible:** Use built-in Postgres node

For questions or issues, check:
- Cloudflare Tunnel logs: `docker logs n8nInstall_cloudflared`
- PostgreSQL logs: `docker logs n8nInstall_postgres`
- Caddy logs: `docker logs n8nInstall_caddy`
