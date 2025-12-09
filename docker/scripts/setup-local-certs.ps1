# PowerShell script to set up SSL certificate structure for local deployment
# This script creates the required directory structure and maps certificates

$certBase = "C:\Users\vvssi\OneDrive\Projects\AI Project\SIRA AI\Certs\sira-ca"
$targetBase = "C:\opt\sira-ai\ssl"

Write-Host "Setting up SSL certificate structure for local deployment..."
Write-Host ""

# Create target directory structure
Write-Host "Creating directory structure..."
New-Item -Path "$targetBase\ca" -ItemType Directory -Force | Out-Null
New-Item -Path "$targetBase\postgres" -ItemType Directory -Force | Out-Null
New-Item -Path "$targetBase\redis" -ItemType Directory -Force | Out-Null
New-Item -Path "$targetBase\nginx" -ItemType Directory -Force | Out-Null

    Write-Host "[OK] Directory structure created"
Write-Host ""

# Copy CA certificate
Write-Host "Copying CA certificate..."
if (Test-Path "$certBase\server\ca\ca.crt") {
    Copy-Item -Path "$certBase\server\ca\ca.crt" -Destination "$targetBase\ca\ca.crt" -Force
    Write-Host "[OK] CA certificate copied"
} else {
    Write-Host "[ERROR] CA certificate not found at: $certBase\server\ca\ca.crt"
    exit 1
}

# Check for PostgreSQL client certificates
Write-Host ""
Write-Host "Checking PostgreSQL client certificates..."
$postgresClientCert = $null
$postgresClientKey = $null

# Check in app folder
if (Test-Path "$certBase\app\postgres") {
    $postgresClientCert = Get-ChildItem -Path "$certBase\app\postgres" -Filter "*client*.crt" | Select-Object -First 1
    $postgresClientKey = Get-ChildItem -Path "$certBase\app\postgres" -Filter "*client*.key" | Select-Object -First 1
}

# If not found, check if we can use server certs (for testing only)
if (-not $postgresClientCert) {
    Write-Host "⚠️  PostgreSQL client certificates not found in app folder"
    Write-Host "   Checking if server certificates can be used for testing..."
    if (Test-Path "$certBase\server\postgres\postgres-server.crt") {
        Write-Host "   ⚠️  WARNING: Using server certificates for client connection (not recommended for production)"
        Write-Host "   Please request client certificates from infrastructure team"
        Copy-Item -Path "$certBase\server\postgres\postgres-server.crt" -Destination "$targetBase\postgres\postgres-client.crt" -Force
        Copy-Item -Path "$certBase\server\postgres\postgres-server.key" -Destination "$targetBase\postgres\postgres-client.key" -Force
        Write-Host "   ✅ Copied server certificates as client certificates (temporary)"
    } else {
        Write-Host "   ❌ PostgreSQL certificates not found"
        Write-Host "   Please contact infrastructure team to generate client certificates"
        exit 1
    }
} else {
    Copy-Item -Path $postgresClientCert.FullName -Destination "$targetBase\postgres\postgres-client.crt" -Force
    Copy-Item -Path $postgresClientKey.FullName -Destination "$targetBase\postgres\postgres-client.key" -Force
    Write-Host "[OK] PostgreSQL client certificates copied"
}

# Check for Redis client certificates
Write-Host ""
Write-Host "Checking Redis client certificates..."
$redisClientCert = $null
$redisClientKey = $null

# Check in app folder
if (Test-Path "$certBase\app\redis") {
    $redisClientCert = Get-ChildItem -Path "$certBase\app\redis" -Filter "*client*.crt" | Select-Object -First 1
    $redisClientKey = Get-ChildItem -Path "$certBase\app\redis" -Filter "*client*.key" | Select-Object -First 1
}

# If not found, check server folder
if (-not $redisClientCert) {
    Write-Host "⚠️  Redis client certificates not found in app folder"
    if (Test-Path "$certBase\server\redis") {
        $redisServerCert = Get-ChildItem -Path "$certBase\server\redis" -Filter "*.crt" | Select-Object -First 1
        $redisServerKey = Get-ChildItem -Path "$certBase\server\redis" -Filter "*.key" | Select-Object -First 1
        if ($redisServerCert) {
            Write-Host "   ⚠️  WARNING: Using server certificates for client connection (not recommended for production)"
            Copy-Item -Path $redisServerCert.FullName -Destination "$targetBase\redis\redis-client.crt" -Force
            Copy-Item -Path $redisServerKey.FullName -Destination "$targetBase\redis\redis-client.key" -Force
            Write-Host "   [OK] Copied server certificates as client certificates (temporary)"
        } else {
            Write-Host "   ❌ Redis certificates not found"
            Write-Host "   Please contact infrastructure team to generate client certificates"
            exit 1
        }
    } else {
        Write-Host "   ❌ Redis certificates not found"
        exit 1
    }
} else {
    Copy-Item -Path $redisClientCert.FullName -Destination "$targetBase\redis\redis-client.crt" -Force
    Copy-Item -Path $redisClientKey.FullName -Destination "$targetBase\redis\redis-client.key" -Force
    Write-Host "[OK] Redis client certificates copied"
}

# Copy Nginx certificates if available
Write-Host ""
Write-Host "Checking Nginx certificates..."
if (Test-Path "$certBase\server\nginx") {
    $nginxCert = Get-ChildItem -Path "$certBase\server\nginx" -Filter "*.crt" | Select-Object -First 1
    $nginxKey = Get-ChildItem -Path "$certBase\server\nginx" -Filter "*.key" | Select-Object -First 1
    if ($nginxCert -and $nginxKey) {
        Copy-Item -Path $nginxCert.FullName -Destination "$targetBase\nginx\cert.pem" -Force
        Copy-Item -Path $nginxKey.FullName -Destination "$targetBase\nginx\key.pem" -Force
        Write-Host "[OK] Nginx certificates copied"
    } else {
        Write-Host "⚠️  Nginx certificates not found - will need to be configured separately"
    }
} else {
    Write-Host "⚠️  Nginx certificates not found - will need to be configured separately"
}

Write-Host ""
Write-Host "[OK] SSL certificate setup complete!"
Write-Host ""
Write-Host "Certificate location: $targetBase"
Write-Host ""
Write-Host "Note: If client certificates are not available, please contact the"
Write-Host "infrastructure team to generate them. Server certificates can be used"
Write-Host "for testing but are not recommended for production."
Write-Host ""

