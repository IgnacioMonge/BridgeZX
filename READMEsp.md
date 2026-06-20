# Sistema de Transmision BridgeZX

![BridgeZX Banner](images/bridgezx_banner.jpg)

> English version: [README.md](README.md)

**BridgeZX** envia archivos desde un PC Windows a la tarjeta SD de un ZX Spectrum por Wi-Fi. El Spectrum ejecuta un pequeno servidor como comando DOT de esxDOS, y el cliente PowerShell del PC envia uno o varios archivos en cola.

Version actual: **v0.5.2**

## Caracteristicas

- **Servidor divMMC / ZX-Uno UART**: ruta UART hardware ajustada para ESP8266 con firmware AT en el puerto `6144`.
- **Comando DOT de esxDOS**: copia `brgzx` a `/BIN` y arrancalo con `.brgzx`.
- **Cola multifichero**: arrastra archivos o carpetas al cliente Windows, reordena la cola y envia el lote en una sola sesion TCP.
- **Integridad**: cada fichero lleva CRC-16; el cliente solo avanza tras recibir un ACK real del servidor.
- **Escritura directa en SD**: el servidor Z80 escribe mediante esxDOS, comprueba espacio libre y mantiene un limite de seguridad de 2 MB por fichero.
- **UI responsiva**: progreso total, ETA, progreso en la barra de tareas, sondeo de conexion, pausa de monitorizacion y sonido al completar.
- **Flujo seguro ante errores**: timeouts, fallos CRC, directorios protegidos y disco lleno paran la cola en vez de marcar falso exito.

## Requisitos de hardware

- ZX Spectrum 48K/128K/+2/+3 o clon compatible.
- DivMMC/DivIDE o similar con esxDOS.
- Modulo Wi-Fi ESP8266/ESP-12 accesible por la ruta UART ZX-Uno/divMMC usada por BridgeZX.

## Instalacion

### Servidor Spectrum

1. Compila o descarga el asset `brgzx` de la release.
2. Copia `brgzx` a `/BIN` en la SD del Spectrum.
3. Arrancalo desde BASIC:

```basic
.brgzx
```

El servidor escucha en el puerto TCP `6144`.

### Cliente Windows

Usa `client/BridgeZX_FINAL.ps1` de la release, o generarlo localmente:

```powershell
powershell -ExecutionPolicy Bypass -File .\client\build.ps1
powershell -ExecutionPolicy Bypass -File .\client\BridgeZX_FINAL.ps1
```

## Compilacion

Servidor: requiere `sjasmplus` y `make`.

```bash
cd server
make all
```

Salidas:

- `server/build/brgzx` - comando DOT esxDOS
- `server/build/brgzx.bin` - binario crudo

Bundle del cliente:

```powershell
powershell -ExecutionPolicy Bypass -File .\client\build.ps1
```

## Assets de release

Una release normal incluye:

- `brgzx`
- `brgzx.bin`
- `BridgeZX_FINAL.ps1`
- opcionalmente `BridgeZX.exe` si se compila con ps2exe

## Notas

BridgeZX esta ajustado para hardware real. Si una configuracion ESP/UART nueva falla, valida senal Wi-Fi, firmware AT del ESP, puerto TCP `6144` y salud de escritura de la SD antes de cambiar el pacing.
