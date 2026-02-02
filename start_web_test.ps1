# Script para iniciar o app Flutter Web e expor via ngrok
# Uso: .\start_web_test.ps1

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   PERTIN - Iniciador de Testes Web   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$PORT = 8080

# Define o caminho do projeto - usa o diretório do script ou o caminho absoluto
if ($PSScriptRoot) {
    $PROJECT_PATH = $PSScriptRoot
} else {
    $PROJECT_PATH = "c:\Users\Rafael\Desktop\pertin"
}

# Verifica se o pubspec.yaml existe (confirma que é um projeto Flutter)
if (-not (Test-Path "$PROJECT_PATH\pubspec.yaml")) {
    Write-Host "ERRO: pubspec.yaml não encontrado em $PROJECT_PATH" -ForegroundColor Red
    Write-Host "Certifique-se de que o script está na pasta do projeto." -ForegroundColor Red
    exit 1
}

Write-Host "Projeto: $PROJECT_PATH" -ForegroundColor Gray
Write-Host ""

# Função para limpar processos ao sair
function Cleanup {
    Write-Host ""
    Write-Host "Encerrando processos..." -ForegroundColor Yellow
    
    # Mata processos do Flutter e ngrok
    Get-Process -Name "dart" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Process -Name "ngrok" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    
    Write-Host "Processos encerrados!" -ForegroundColor Green
}

# Registra o cleanup para quando o script for interrompido
Register-EngineEvent PowerShell.Exiting -Action { Cleanup } | Out-Null

# Verifica se o Flutter está instalado
Write-Host "[1/4] Verificando Flutter..." -ForegroundColor Yellow
$flutterVersion = flutter --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: Flutter não encontrado. Instale o Flutter primeiro." -ForegroundColor Red
    exit 1
}
Write-Host "Flutter OK!" -ForegroundColor Green

# Verifica se o ngrok está instalado
Write-Host "[2/4] Verificando ngrok..." -ForegroundColor Yellow
$ngrokVersion = ngrok version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: ngrok não encontrado. Instalando..." -ForegroundColor Yellow
    winget install ngrok.ngrok
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRO: Não foi possível instalar o ngrok." -ForegroundColor Red
        exit 1
    }
}
Write-Host "ngrok OK!" -ForegroundColor Green

# Mata processos anteriores que possam estar usando a porta
Write-Host "[3/4] Liberando porta $PORT..." -ForegroundColor Yellow
$processOnPort = Get-NetTCPConnection -LocalPort $PORT -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue
if ($processOnPort) {
    Stop-Process -Id $processOnPort -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}
Write-Host "Porta $PORT liberada!" -ForegroundColor Green

# Inicia o Flutter Web Server em background
Write-Host "[4/4] Iniciando Flutter Web Server..." -ForegroundColor Yellow
Write-Host "Diretorio: $PROJECT_PATH" -ForegroundColor Gray
Set-Location $PROJECT_PATH

# Primeiro, faz flutter pub get para garantir dependências
Write-Host "Verificando dependencias..." -ForegroundColor Yellow
flutter pub get | Out-Null

$flutterJob = Start-Job -ScriptBlock {
    param($path, $port)
    Set-Location $path
    # Especifica o arquivo main.dart e o target
    flutter run -d web-server --web-port=$port --web-hostname=0.0.0.0 --target=lib/main.dart 2>&1
} -ArgumentList $PROJECT_PATH, $PORT

# Aguarda o servidor Flutter iniciar
Write-Host "Aguardando servidor Flutter iniciar..." -ForegroundColor Yellow
$maxWait = 120  # 2 minutos máximo
$waited = 0
$serverReady = $false

while ($waited -lt $maxWait -and -not $serverReady) {
    Start-Sleep -Seconds 2
    $waited += 2
    
    # Verifica se a porta está escutando
    $listening = Get-NetTCPConnection -LocalPort $PORT -State Listen -ErrorAction SilentlyContinue
    if ($listening) {
        $serverReady = $true
    }
    
    # Mostra progresso
    Write-Host "." -NoNewline
}

Write-Host ""

if (-not $serverReady) {
    Write-Host "ERRO: Servidor Flutter não iniciou a tempo." -ForegroundColor Red
    Write-Host "Verifique se há erros no projeto." -ForegroundColor Red
    Stop-Job $flutterJob -ErrorAction SilentlyContinue
    Remove-Job $flutterJob -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "Servidor Flutter iniciado!" -ForegroundColor Green
Write-Host ""

# Inicia o ngrok
Write-Host "Iniciando ngrok..." -ForegroundColor Yellow

$ngrokJob = Start-Job -ScriptBlock {
    param($port)
    ngrok http $port 2>&1
} -ArgumentList $PORT

# Aguarda o ngrok iniciar e pega a URL
Start-Sleep -Seconds 3

# Pega a URL do ngrok via API local
$maxRetries = 10
$retries = 0
$ngrokUrl = $null

while ($retries -lt $maxRetries -and -not $ngrokUrl) {
    try {
        $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -ErrorAction SilentlyContinue
        $ngrokUrl = $tunnels.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -ExpandProperty public_url -First 1
    } catch {
        Start-Sleep -Seconds 1
        $retries++
    }
}

if (-not $ngrokUrl) {
    Write-Host "AVISO: Não foi possível obter a URL do ngrok automaticamente." -ForegroundColor Yellow
    Write-Host "Acesse http://127.0.0.1:4040 para ver a URL." -ForegroundColor Yellow
    $ngrokUrl = "http://127.0.0.1:4040"
}

# Exibe informações
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "         APP INICIADO COM SUCESSO!     " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "URL PUBLICA (compartilhe esta):" -ForegroundColor Cyan
Write-Host ""
Write-Host "  $ngrokUrl" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Gray
Write-Host "URL Local:      http://localhost:$PORT" -ForegroundColor Gray
Write-Host "Dashboard ngrok: http://127.0.0.1:4040" -ForegroundColor Gray
Write-Host "----------------------------------------" -ForegroundColor Gray
Write-Host ""
Write-Host "Pressione CTRL+C para encerrar..." -ForegroundColor Yellow
Write-Host ""

# Copia URL para a área de transferência
try {
    $ngrokUrl | Set-Clipboard
    Write-Host "(URL copiada para a area de transferencia!)" -ForegroundColor Green
} catch {
    # Ignora se não conseguir copiar
}

# Mantém o script rodando e mostra logs
try {
    while ($true) {
        # Verifica se os jobs ainda estão rodando
        $flutterState = Get-Job -Id $flutterJob.Id -ErrorAction SilentlyContinue | Select-Object -ExpandProperty State
        $ngrokState = Get-Job -Id $ngrokJob.Id -ErrorAction SilentlyContinue | Select-Object -ExpandProperty State
        
        if ($flutterState -eq "Failed" -or $flutterState -eq "Stopped") {
            Write-Host "Flutter parou inesperadamente!" -ForegroundColor Red
            Receive-Job $flutterJob
            break
        }
        
        if ($ngrokState -eq "Failed" -or $ngrokState -eq "Stopped") {
            Write-Host "ngrok parou inesperadamente!" -ForegroundColor Red
            Receive-Job $ngrokJob
            break
        }
        
        Start-Sleep -Seconds 5
    }
} finally {
    # Cleanup
    Cleanup
    Stop-Job $flutterJob -ErrorAction SilentlyContinue
    Stop-Job $ngrokJob -ErrorAction SilentlyContinue
    Remove-Job $flutterJob -ErrorAction SilentlyContinue
    Remove-Job $ngrokJob -ErrorAction SilentlyContinue
}
