@echo off
setlocal
cd /d "%~dp0"
echo ============================================
echo   Setup do projeto Refugio (Roblox + Rojo)
echo ============================================
echo.

REM --- Git ---
where git >nul 2>nul
if errorlevel 1 (
    echo [Git] nao encontrado. Instalando via winget...
    winget install --id Git.Git -e --source winget
    echo.
    echo Git instalado. FECHE esta janela e rode setup.bat de novo
    echo para o Windows reconhecer o Git.
    pause
    exit /b 0
) else (
    echo [Git] ok
)

REM --- VS Code ---
where code >nul 2>nul
if errorlevel 1 (
    echo [VS Code] nao encontrado. Instalando via winget...
    winget install --id Microsoft.VisualStudioCode -e --source winget
    echo.
    echo VS Code instalado. FECHE esta janela e rode setup.bat de novo.
    pause
    exit /b 0
) else (
    echo [VS Code] ok
)

REM --- Rokit ---
where rokit >nul 2>nul
if errorlevel 1 (
    echo.
    echo [Rokit] nao encontrado.
    echo Baixe o instalador do Windows em:
    echo   https://github.com/rojo-rbx/rokit/releases
    echo Execute o rokit-...-windows-x86_64 baixado com o argumento "self-install"
    echo Ex.: abra o terminal na pasta do download e rode:
    echo   .\rokit-windows-x86_64.exe self-install
    echo Depois FECHE esta janela e rode setup.bat de novo.
    echo.
    start https://github.com/rojo-rbx/rokit/releases
    pause
    exit /b 1
) else (
    echo [Rokit] ok
)

echo.
echo --- Git ---
if not exist ".git" (
    git init
) else (
    echo repositorio ja existe
)

echo.
echo --- Rojo via Rokit ---
if not exist "rokit.toml" (
    rokit init
)
rokit add rojo-rbx/rojo
rokit install

echo.
echo --- Plugin do Rojo no Roblox Studio ---
rojo plugin install

echo.
echo --- Extensoes do VS Code ---
call code --install-extension JohnnyMorganz.luau-lsp
call code --install-extension evaera.vscode-rojo

echo.
echo ============================================
echo  Pronto! Falta so o que e manual (ver LEIA-ME.txt):
echo   1. Roblox Studio: criar Baseplate e publicar como privado
echo   2. Game Settings ^> Security ^> Enable Studio Access to API Services
echo   3. Rodar iniciar.bat e clicar em Connect no plugin do Rojo
echo ============================================
pause
