# =============================================================================
# TechstoreVendas | iniciar_previa.ps1
# Sobe a API local para a PRÉVIA do dashboard (desenvolvimento).
#   * Sem api\.env: usa a conexão de desenvolvimento techstore_dev_app (Windows/SSPI,
#     sem senha), com sessões forçadas somente leitura pela própria API.
#   * Com api\.env: usa o que estiver nele (techstore_api_leitor).
#   * Libera CORS só para a Live Preview do VS Code (127.0.0.1:3000 e localhost:3000).
# Uso (na raiz do projeto):   powershell -ExecutionPolicy Bypass -File api\iniciar_previa.ps1
# Para parar: Ctrl+C nesta janela.
# =============================================================================

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path ".env")) {
    $env:TECHSTORE_PG_USUARIO = "techstore_dev_app"
    Write-Host "api\.env não encontrado: usando a conexão de desenvolvimento (techstore_dev_app, somente leitura)."
} else {
    Write-Host "Usando a configuração de api\.env."
}
$env:TECHSTORE_API_ORIGENS_DEV = "http://127.0.0.1:3000,http://localhost:3000"

Write-Host "API em http://127.0.0.1:8000  ·  Live Preview: abra web\index.html (porta 3000)."
& ".\.venv\Scripts\python.exe" -m techstore_api
