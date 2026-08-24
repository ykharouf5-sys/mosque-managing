[CmdletBinding()]
param(
    [string]$Alias = "upload"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$androidRoot = Join-Path $projectRoot "android"
$keystoreDirectory = Join-Path $androidRoot "keystores"
$keystorePath = Join-Path $keystoreDirectory "studentry-upload.jks"
$propertiesPath = Join-Path $androidRoot "key.properties"

if ((Test-Path -LiteralPath $keystorePath) -or (Test-Path -LiteralPath $propertiesPath)) {
    throw "Refusing to overwrite an existing Android upload key or key.properties file."
}

$keytoolCandidates = @()
if ($env:JAVA_HOME) {
    $keytoolCandidates += Join-Path $env:JAVA_HOME "bin\keytool.exe"
}
$keytoolCandidates += "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
$keytoolCandidates += "C:\Program Files\Java\jdk-17\bin\keytool.exe"

$keytool = $keytoolCandidates |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1

if (-not $keytool) {
    $keytoolCommand = Get-Command keytool.exe -ErrorAction SilentlyContinue
    if ($keytoolCommand) {
        $keytool = $keytoolCommand.Source
    }
}

if (-not $keytool) {
    throw "keytool.exe was not found. Install Android Studio or set JAVA_HOME to a JDK."
}

$passwordBytes = New-Object byte[] 48
$randomNumberGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$randomNumberGenerator.GetBytes($passwordBytes)
$randomNumberGenerator.Dispose()
$password = [Convert]::ToBase64String($passwordBytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")

New-Item -ItemType Directory -Path $keystoreDirectory -Force | Out-Null

try {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $keytool `
        -genkeypair `
        -keystore $keystorePath `
        -storetype PKCS12 `
        -storepass $password `
        -keypass $password `
        -alias $Alias `
        -keyalg RSA `
        -keysize 4096 `
        -validity 10000 `
        -dname "CN=Studentry Upload Key, O=Studentry" `
        -noprompt 2>&1 | Out-Null
    $keytoolExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference

    if ($keytoolExitCode -ne 0) {
        throw "keytool failed with exit code $keytoolExitCode."
    }

    $properties = @(
        "storePassword=$password"
        "keyPassword=$password"
        "keyAlias=$Alias"
        "storeFile=../keystores/studentry-upload.jks"
    )
    [System.IO.File]::WriteAllLines($propertiesPath, $properties, [System.Text.UTF8Encoding]::new($false))

    $fingerprintOutput = & $keytool -list -v -keystore $keystorePath -storepass $password -alias $Alias 2>&1
    $sha256Line = $fingerprintOutput | Where-Object { $_ -match "SHA256:" } | Select-Object -First 1

    Write-Host "Android upload key created successfully."
    Write-Host "Keystore: $keystorePath"
    Write-Host "Properties: $propertiesPath"
    if ($sha256Line) {
        Write-Host ($sha256Line.ToString().Trim())
    }
    Write-Host "Back up both ignored files securely. The password is intentionally not printed."
}
catch {
    if ((Test-Path -LiteralPath $keystorePath) -and -not (Test-Path -LiteralPath $propertiesPath)) {
        Remove-Item -LiteralPath $keystorePath -Force
    }
    throw
}
finally {
    [Array]::Clear($passwordBytes, 0, $passwordBytes.Length)
    $password = $null
}
