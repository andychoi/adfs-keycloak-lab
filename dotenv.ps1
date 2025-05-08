<#
.SYNOPSIS
    Load key=value pairs from a .env file into $env: variables.
.DESCRIPTION
    - Ignores empty lines and comments
    - Automatically trims values
    - Can be dot-sourced to apply globally
.EXAMPLE
    . .\dotenv.ps1 -Path ".env"
#>
param(
    [string]$Path = ".env"
)

if (-not (Test-Path $Path)) {
    Write-Warning "No .env file found at path: $Path"
    return
}

Get-Content $Path | ForEach-Object {
    $_ = $_.Trim()
    if (-not $_ -or $_.StartsWith("#")) {
        return
    }

    if ($_ -match "^\s*([^=]+?)\s*=\s*(.+?)\s*$") {
        $key = $matches[1]
        $value = $matches[2].Trim('"')  # remove optional quotes
        $env:$key = $value
    }
}
