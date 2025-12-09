# How to Access SIRA Community Application

**Last Updated:** December 9, 2025

## Quick Access

### Local Access (Development/Testing)

The application is accessible via Nginx reverse proxy on the following ports:

#### Option 1: HTTPS (Recommended)
```
https://localhost:8443
```

#### Option 2: HTTP (Redirects to HTTPS)
```
http://localhost:8080
```
*Note: HTTP automatically redirects to HTTPS*

---

## Port Configuration

- **HTTP Port**: `8080` (host) → `80` (container)
- **HTTPS Port**: `8443` (host) → `443` (container)

These ports are configured via environment variables:
- `COMMUNITY_HTTP_PORT` (default: 80, mapped to 8080)
- `COMMUNITY_HTTPS_PORT` (default: 443, mapped to 8443)

---

## Server Name Configuration

The application is configured with server name:
- **Server Name**: `community.sira.ai`

For local access, you can:
1. **Use localhost** (works with certificate warnings)
2. **Add to hosts file** (for proper domain resolution):
   ```
   127.0.0.1  community.sira.ai
   ```
   Then access: `https://community.sira.ai:8443`

---

## SSL Certificate Notes

✅ **Certificate Fixed**: The application now uses the correct **server certificate** (`nginx-server.crt`) instead of a client certificate.

⚠️ **Certificate Warning**: When accessing via `localhost`, you may see a certificate warning because the certificate is issued for `community.sira.ai`, not `localhost`.

**Options:**
1. **Accept the warning** (for local testing only) - The certificate is valid, just for a different hostname
2. **Add to hosts file** and use `community.sira.ai:8443`:
   ```
   127.0.0.1  community.sira.ai
   ```
3. **Import the CA certificate** to your browser/system trust store

**Note**: The `ERR_SSL_KEY_USAGE_INCOMPATIBLE` error has been fixed by using the correct server certificate.

---

## Health Check Endpoints

### Application Health
```
https://localhost:8443/health
```
Returns: Application health status

### Nginx Health
```
http://localhost:8080/health
```
Returns: `healthy`

---

## Access from Other Devices on Network

If you want to access from other devices on your local network:

1. **Find your local IP address:**
   ```bash
   # Windows
   ipconfig
   
   # Look for IPv4 Address (e.g., 192.168.1.100)
   ```

2. **Access via:**
   ```
   https://YOUR_IP_ADDRESS:8443
   ```

3. **Update hosts file** on the remote device:
   ```
   YOUR_IP_ADDRESS  community.sira.ai
   ```

---

## Troubleshooting

### Cannot Access Application

1. **Check if services are running:**
   ```bash
   docker ps --filter "name=sira-community"
   ```
   All services should show "healthy" status.

2. **Check if ports are listening:**
   ```bash
   # Windows
   netstat -an | findstr "8080"
   netstat -an | findstr "8443"
   ```

3. **Check Nginx logs:**
   ```bash
   docker logs sira-community-nginx --tail 50
   ```

4. **Check App logs:**
   ```bash
   docker logs sira-community-app --tail 50
   ```

### Certificate Errors

If you see certificate errors:
- The certificate is valid for `community.sira.ai`
- For local testing, you can accept the warning
- For production, ensure DNS points to your server

### Connection Refused

If you get "connection refused":
- Verify Docker containers are running
- Check firewall settings (Windows Firewall may block ports)
- Verify port mappings in `docker-compose.sira-community.app.yml`

---

## Production Access

For production deployment:

1. **Configure DNS**: Point `community.sira.ai` to your server IP
2. **Use standard ports**: Change port mappings to 80/443
3. **Update firewall**: Allow ports 80 and 443
4. **SSL certificates**: Ensure certificates are valid for the domain

---

## Quick Test Commands

```bash
# Test HTTP endpoint
curl -I http://localhost:8080

# Test HTTPS endpoint (ignore certificate)
curl -I -k https://localhost:8443

# Test health endpoint
curl -k https://localhost:8443/health

# Test from inside container
docker exec sira-community-nginx wget -q -O- http://127.0.0.1/health
```

---

## Summary

✅ **Primary Access**: `https://localhost:8443`  
✅ **HTTP Redirect**: `http://localhost:8080` → redirects to HTTPS  
✅ **Health Check**: `https://localhost:8443/health`  
✅ **Server Name**: `community.sira.ai`  

**Note**: For local testing, you may need to accept certificate warnings when using `localhost`.

