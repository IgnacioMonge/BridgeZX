
# Sistema de Transmisión BridgeZX

![BridgeZX Banner](images/bridgezx_banner.jpg)

> *> *English version here: [READMR.md](README.md)*
> 
**BridgeZX** es una herramienta de transmisión de archivos para ZX Spectrum que tiende un puente entre tu PC moderno y tu máquina de 8 bits. Implementa una **estructura asíncrona cliente-servidor** para enviar archivos (TAP, TRD, SCR, Z80, etc.) por Wi-Fi directamente a la tarjeta SD del Spectrum.

El sistema utiliza un módulo **ESP-12 (ESP8266)** conectado a través del chip de sonido **AY-3-8912** para establecer el enlace inalámbrico, donde el Spectrum actúa como nodo receptor (Servidor) y el PC como emisor (Cliente).

## 🚀 Características

* **Transferencia a "Alta Velocidad"**: A ver, seamos sinceros. Funciona a **9600 baudios** a través del chip AY. Es una velocidad absurda comparada con cargar una cinta de casete (adiós a los 5 minutos de espera), ¡pero tampoco esperes fibra óptica! ;)
* **Arquitectura Asíncrona Cliente-Servidor**: El sistema gestiona la recepción de paquetes, el buffer circular, la escritura en SD y la interfaz de usuario de forma asíncrona para garantizar la estabilidad en la CPU Z80.
* **Doble Modo de Operación**:
    * **Comando Punto (`.bridgezx`)**: La forma profesional. Se integra en esxDOS. Solo escribe `.bridgezx` y el servidor quedará a la espera.
    * **Binario Estándar (`.bin`)**: Para cargar con `LOAD ""` o `RANDOMIZE USR`.
* **Escritura Directa en SD**: Usa las llamadas al sistema de esxDOS para volcar el flujo de datos a la tarjeta, saltándose las rutinas de la ROM.
* **Integridad a Prueba de Balas**: Verificación **CRC-16** en cada paquete de archivo.
* **Interfaz Retro-Futurista**:
    * Barra de progreso en tiempo real.
    * **Feedback Visual "Matrix"**: El borde parpadea con ruido binario durante la carga, confirmando visualmente la actividad del puerto UART.
    * Estados por colores: Azul (Esperando), Verde (Éxito), Rojo (Error).
* **Seguridad Ante Todo**: Comprobación previa de espacio en SD y límite de seguridad de 2MB por archivo.
* **Limpieza de Pantalla Inteligente**: Una rutina de vídeo personalizada que borra los listados BASIC antiguos de la memoria para una interfaz limpia.

## 🛠 Requisitos de Hardware

* **ZX Spectrum** (48k, 128k, +2, +3, o clones como ZX-Uno/Next).
* **Interfaz de Almacenamiento**: DivMMC, DivIDE, o similar con **esxDOS**.
* **Interfaz Wi-Fi**: Módulo **ESP-12 (ESP8266)** conectado vía UART al chip **AY-3-8912** (el estándar en la mayoría de interfaces modernas).

## 📦 Instalación y Uso

### 1. Como Comando de Sistema (Recomendado)
1.  Copia el archivo `bridgezx` (sin extensión) a la carpeta `/BIN` de la SD.
2.  Arranca el Spectrum.
3.  Escribe esto en BASIC:
    ```basic
    .bridgezx
    ```
4.  El Spectrum escuchará en el **Puerto 6144**. Usa el Cliente de PC para enviar archivos.

### 2. Como Programa Normal
1.  Copia `bridgezx.bin` y `BRIDGEZX.BAS` a la SD.
2.  Carga como en los viejos tiempos:
    ```basic
    LOAD "BRIDGEZX.BAS"
    ```

## ⚙️ Compilación

Escrito en Ensamblador Z80. Necesitas **SjASMPlus** (v1.21.0 o superior).

### Compilar el Comando Punto (`.bridgezx`)
Usamos el flag `-DDOT` para mover el código a la dirección `$2000` (espacio reservado de esxDOS).
```bash
sjasmplus -DDOT dot.asm
