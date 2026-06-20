# BridgeZX Windows Client

Build the bundled client from this directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

Run the generated script:

```powershell
powershell -ExecutionPolicy Bypass -File .\BridgeZX_FINAL.ps1
```

Optional EXE build, if `ps2exe` is installed:

```powershell
Invoke-ps2exe .\BridgeZX_FINAL.ps1 .\BridgeZX.exe -noConsole -sta -iconFile .\bridgezx.ico
```
