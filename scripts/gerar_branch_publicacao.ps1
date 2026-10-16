<#
.SYNOPSIS
  Gera (ou atualiza) o branch "publicacao": um espelho dos commits de "main"
  sem os arquivos .pbix, pronto para ser enviado ao GitHub.

.DESCRIPTION
  Os relatórios .pbix ficam só no repositório local: contêm identificadores do
  Power BI Service (Connections), um bloco de credenciais criptografado
  (SecurityBindings) e um modelo de dados binário que não pode ser auditado.

  O script NÃO altera "main", o diretório de trabalho nem o índice: cada commit
  de "main" é recriado num índice temporário, sem os caminhos excluídos, com a
  mesma mensagem e data. É incremental: commits já espelhados (marcados com
  "Espelho-de: <sha>") não são refeitos, então o branch só cresce e pode ser
  enviado sem force push.

.PARAMETER Email
  E-mail do autor nos commits publicados. Use o e-mail privado do GitHub
  ("...@users.noreply.github.com", em Settings > Emails) para não expor o
  e-mail pessoal.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\gerar_branch_publicacao.ps1 -Email 12345678+usuario@users.noreply.github.com
#>
param(
    [Parameter(Mandatory = $true)][string]$Email,
    [string]$Nome = "Thiago Miranda",
    [string]$Origem = "main",
    [string]$Branch = "publicacao",
    [string[]]$Excluir = @("powerbi/*.pbix")
)

$ErrorActionPreference = "Stop"
# Mensagens de commit são UTF-8: sem isto, o PowerShell 5.1 corrompe os acentos ao ler a saída do git.
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
Set-Location (git rev-parse --show-toplevel)

if ($Email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { throw "E-mail inválido: $Email" }

# Commits já espelhados no branch de publicação.
$espelhados = @{}
$pai = $null
if (git rev-parse --verify --quiet "refs/heads/$Branch") {
    $pai = (git rev-parse "refs/heads/$Branch").Trim()
    git log --format=%B $Branch | Select-String '^Espelho-de: ([0-9a-f]{40})$' | ForEach-Object { $espelhados[$_.Matches[0].Groups[1].Value] = $true }
}

$indice = Join-Path ([IO.Path]::GetTempPath()) ("indice-publicacao-" + [guid]::NewGuid().ToString("N"))
$novos = 0
try {
    $env:GIT_INDEX_FILE = $indice
    foreach ($commit in (git rev-list --reverse $Origem)) {
        if ($espelhados.ContainsKey($commit)) { continue }
        git read-tree $commit
        git rm --cached -q --ignore-unmatch -- $Excluir | Out-Null
        $arvore = (git write-tree).Trim()

        # A saída do git chega como um array de linhas: juntar com "`n" preserva as quebras.
        $mensagem = ((git log -1 --format=%B $commit) -join "`n").TrimEnd() + "`n`nEspelho-de: $commit`n"
        $arquivoMsg = "$indice.msg"
        [IO.File]::WriteAllText($arquivoMsg, $mensagem, (New-Object Text.UTF8Encoding($false)))

        $env:GIT_AUTHOR_NAME = $Nome; $env:GIT_AUTHOR_EMAIL = $Email
        $env:GIT_COMMITTER_NAME = $Nome; $env:GIT_COMMITTER_EMAIL = $Email
        $env:GIT_AUTHOR_DATE = (git log -1 --format=%aI $commit).Trim()
        $env:GIT_COMMITTER_DATE = (git log -1 --format=%cI $commit).Trim()

        $argumentos = @("commit-tree", $arvore, "-F", $arquivoMsg)
        if ($pai) { $argumentos += @("-p", $pai) }
        $pai = (& git @argumentos).Trim()
        $novos++
        Write-Host ("espelhado: {0} -> {1}  {2}" -f $commit.Substring(0, 7), $pai.Substring(0, 7), (git log -1 --format=%s $commit))
    }
}
finally {
    foreach ($v in "GIT_INDEX_FILE", "GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL", "GIT_AUTHOR_DATE", "GIT_COMMITTER_DATE") {
        Set-Item -Path "env:$v" -Value $null -ErrorAction SilentlyContinue
    }
    foreach ($a in $indice, "$indice.msg", "$indice.lock") { if (Test-Path $a) { [IO.File]::Delete($a) } }
}

if ($novos -gt 0) { git update-ref "refs/heads/$Branch" $pai }

# Conferência: nenhum caminho excluído no branch publicado.
$proibidos = git ls-tree -r --name-only $Branch | Where-Object { $p = $_; $Excluir | Where-Object { $p -like $_ } }
if ($proibidos) { throw "Arquivos excluídos encontrados em ${Branch}: $($proibidos -join ', ')" }
Write-Host "Branch '$Branch': $novos commit(s) novo(s); $((git rev-list --count $Branch).Trim()) no total; nenhum .pbix."
