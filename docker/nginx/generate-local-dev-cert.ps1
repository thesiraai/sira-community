# Generates a local-dev self-signed TLS certificate for nginx
# Output files:
# - docker/nginx/ssl/fullchain.pem
# - docker/nginx/ssl/privkey.pem
#
# Also installs the certificate into the Windows CurrentUser Root trust store
# so browsers trust it for local development.
#
# Usage (from repo root):
#   pwsh -File docker/nginx/generate-local-dev-cert.ps1

$ErrorActionPreference = "Stop"

$dnsName = "local.community.sira.ai"
$sslDir = Join-Path $PSScriptRoot "ssl"

New-Item -ItemType Directory -Force -Path $sslDir | Out-Null

$fullchainPath = Join-Path $sslDir "fullchain.pem"
$privkeyPath   = Join-Path $sslDir "privkey.pem"
$cerPath       = Join-Path $sslDir "$dnsName.cer"

Write-Host "Generating self-signed cert for $dnsName ..." -ForegroundColor Cyan

$rsa = [System.Security.Cryptography.RSA]::Create(2048)
$hashAlg = [System.Security.Cryptography.HashAlgorithmName]::SHA256
$padding = [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
$req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new("CN=$dnsName", $rsa, $hashAlg, $padding)

$san = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
$san.AddDnsName($dnsName)
$req.CertificateExtensions.Add($san.Build())

$req.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($false, $false, 0, $false))
$req.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new(
    ([System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor
     [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment),
    $false
))

$serverAuthOid = [System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.1") # TLS Web Server Authentication
$ekuOids = [System.Security.Cryptography.OidCollection]::new()
$null = $ekuOids.Add($serverAuthOid)
$eku = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($ekuOids, $false)
$req.CertificateExtensions.Add($eku)

$notBefore = [System.DateTimeOffset]::Now.AddDays(-1)
$notAfter  = $notBefore.AddYears(2)
$cert = $req.CreateSelfSigned($notBefore, $notAfter)

# Write PEM files for nginx
$certPem = $cert.ExportCertificatePem()
$keyPem  = $rsa.ExportPkcs8PrivateKeyPem()

Set-Content -Path $fullchainPath -Value $certPem -NoNewline
Set-Content -Path $privkeyPath   -Value $keyPem  -NoNewline

# Write DER .cer for easy trust-store import
[System.IO.File]::WriteAllBytes($cerPath, $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))

Write-Host "Wrote:" -ForegroundColor Green
Write-Host "  $fullchainPath" -ForegroundColor White
Write-Host "  $privkeyPath" -ForegroundColor White
Write-Host "  $cerPath" -ForegroundColor White

# Install into CurrentUser Root store (no admin required)
try {
  $store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
    [System.Security.Cryptography.X509Certificates.StoreName]::Root,
    [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
  )
  $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
  $store.Add($cert)
  $store.Close()
  Write-Host "Installed cert into CurrentUser Root trust store (Chrome/Edge should trust it)." -ForegroundColor Green
} catch {
  Write-Warning "Could not install certificate into CurrentUser Root store. You can manually trust: $cerPath"
  Write-Warning $_.Exception.Message
}

Write-Host "Done." -ForegroundColor Green


