# SIRA Community Security Hardening Guide

## Production-Grade Security Configuration

This document outlines the security measures implemented in the SIRA Community deployment.

### Container Security

#### 1. Non-Root User Execution
- Application runs as `community` user (UID 1000)
- Entrypoint script switches from root to non-root user using `gosu`
- Prevents privilege escalation attacks

#### 2. Minimal Base Image
- Uses `ruby:3.3-slim` (Debian-based, minimal footprint)
- Only essential packages installed
- `--no-install-recommends` flag reduces attack surface

#### 3. Build-Time Security
- Build tools removed after compilation
- No development dependencies in production image
- Git history removed from image
- Documentation files removed to reduce image size

#### 4. File Permissions
- Strict file permissions: `u=rwX,g=rX,o=`
- Sensitive files (certificates, keys) have restricted permissions
- Logs and temporary directories properly secured

### Network Security

#### 1. mTLS (Mutual TLS)
- All database connections use mTLS
- All Redis connections use mTLS
- Client certificates required for authentication
- CA certificates for chain of trust

#### 2. SSL/TLS Configuration
- TLS 1.2 and TLS 1.3 only
- Strong cipher suites
- Perfect Forward Secrecy enabled
- SSL session tickets disabled

#### 3. Firewall Rules
- Only necessary ports exposed (8080, 8443)
- Internal container communication via Docker network
- No direct database/Redis exposure

### Application Security

#### 1. Environment Variables
- Secrets stored in environment variables (not in code)
- `.env` files excluded from Docker image
- Sensitive data never committed to repository

#### 2. Certificate Management
- Certificates mounted as read-only volumes
- Copied to writable location with proper permissions
- Automatic certificate rotation support

#### 3. Logging and Monitoring
- Comprehensive logging for security events
- Health checks for service availability
- Error tracking and alerting

### Deployment Security

#### 1. Automated Build Process
- Reproducible builds
- Dependency verification
- Security scanning (recommended: add Trivy/Clair)

#### 2. Health Checks
- Application health endpoints
- Container health checks
- Automatic restart on failure

#### 3. Resource Limits
- CPU and memory limits configured
- Prevents resource exhaustion attacks
- Fair resource allocation

### Best Practices

#### 1. Regular Updates
- Keep base images updated
- Regularly update dependencies
- Monitor security advisories

#### 2. Secrets Management
- Use Docker secrets or external secret management
- Rotate certificates regularly
- Never commit secrets to repository

#### 3. Monitoring
- Monitor container logs
- Set up alerts for anomalies
- Regular security audits

### Security Checklist

- [x] Non-root user execution
- [x] Minimal base image
- [x] Build tools removed
- [x] File permissions set correctly
- [x] mTLS for all connections
- [x] Strong SSL/TLS configuration
- [x] Environment variables for secrets
- [x] Health checks enabled
- [x] Resource limits configured
- [ ] Security scanning in CI/CD (recommended)
- [ ] Automated dependency updates (recommended)
- [ ] Log aggregation and monitoring (recommended)

### Additional Recommendations

1. **Add Security Scanning**: Integrate Trivy or Clair for vulnerability scanning
2. **Implement WAF**: Consider adding a Web Application Firewall
3. **Rate Limiting**: Implement rate limiting at Nginx level
4. **DDoS Protection**: Use cloud provider DDoS protection
5. **Backup Strategy**: Regular automated backups
6. **Disaster Recovery**: Document and test recovery procedures



