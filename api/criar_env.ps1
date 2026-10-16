# =============================================================================
# TechstoreVendas | criar_env.ps1
# Cria api\.env com a senha do techstore_api_leitor digitada de forma oculta.
#   * a senha não aparece na tela, no histórico do PowerShell nem em log;
#   * o arquivo fica só com permissão para o seu usuário do Windows;
#   * api\.env é ignorado pelo Git (.gitignore: ".env").
# Uso (na raiz do projeto):
#   powershell -ExecutionPolicy Bypass -File api\criar_env.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$destino = Join-Path $PSScriptRoot ".env"

if (Test-Path $destino) {
    $resp = Read-Host "api\.env já existe. Substituir? (s/N)"
    if ($resp -notin @("s", "S")) { Write-Host "Nada alterado."; exit 0 }
}

$s1 = Read-Host "Senha do techstore_api_leitor" -AsSecureString
$s2 = Read-Host "Repita a senha" -AsSecureString

$b1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s1)
$b2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s2)
try {
    $p1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b1)
    $p2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b2)
    if ($p1 -ne $p2) { throw "As senhas não conferem. Nada foi gravado." }
    if ([string]::IsNullOrEmpty($p1)) { throw "Senha vazia. Nada foi gravado." }
    if ($p1 -match "[`r`n]") { throw "A senha não pode conter quebra de linha." }

    $conteudo = @(
        "# Gerado por api\criar_env.ps1. NÃO versionar, NÃO compartilhar."
        "TECHSTORE_PG_HOST=localhost"
        "TECHSTORE_PG_PORT=5433"
        "TECHSTORE_PG_BANCO=techstore_dev_v3"
        "TECHSTORE_PG_USUARIO=techstore_api_leitor"
        "TECHSTORE_PG_SENHA=$p1"
        "TECHSTORE_API_HOST=127.0.0.1"
        "TECHSTORE_API_PORTA=8000"
    )
    [IO.File]::WriteAllLines($destino, [string[]]$conteudo, (New-Object Text.UTF8Encoding($false)))
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b1)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b2)
    Remove-Variable p1, p2 -ErrorAction SilentlyContinue
}

# Permissão só para o usuário atual (remove a herança da pasta).
icacls $destino /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null

Write-Host "api\.env criado com permissão restrita a $env:USERNAME. A senha não foi exibida."
