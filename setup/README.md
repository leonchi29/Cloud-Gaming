# Setup — Instalación por PC

Cloud Gaming usa **dos PCs diferentes**, cada uno con su propio instalador:

| PC | Rol | Instalador |
| --- | --- | --- |
| **PC dev** | Despliega la web y el backend en Railway | `start-dev.bat` |
| **PC de stream** | El PC Windows 10 que controlas remotamente | `start-stream.bat` |

---

## 1. PC dev — Despliegue en Railway

En este PC (donde está el código y Railway CLI autenticado):

```
Doble clic en start-dev.bat
```

Hace todo automáticamente:

1. Verifica Node.js, npm y Railway CLI
2. Instala y compila backend y frontend
3. Genera un `AGENT_TOKEN` seguro
4. Crea el proyecto Railway, los servicios, despliega y genera dominios
5. **Imprime 3 datos: URL pública, URL del backend y AGENT_TOKEN**

Anota esos 3 datos: los necesitas en el PC de stream.

---

## 2. PC de stream — Instalación del agente

En el PC Windows 10 que vas a controlar (copia esta carpeta `setup/`, `agent/` y `scripts/`):

```
Doble clic en start-stream.bat
```

Te pedirá la **URL del backend** y el **AGENT_TOKEN** (los que imprimió el PC dev). Después hace todo automáticamente:

1. Verifica Node.js
2. Instala y compila el agente (robotjs nativo para teclado/ratón)
3. Genera `agent\.env` con la URL y el token
4. Configura energía de Windows (nunca suspender/hibernar/apagar discos/red)
5. Configura modo tapa cerrada
6. Instala el agente como tarea programada (arranque con Windows, reinicio automático si falla)
7. Verifica que quedó en ejecución

**Solo se ejecuta una vez.** Después el agente arranca solo con Windows y se reconecta solo ante caídas.

---

## Uso diario

1. El PC de stream está encendido (el agente corre solo en segundo plano)
2. Abre la **URL pública** en Chrome, Edge o Firefox desde cualquier dispositivo
3. Pulsa **Conectar**

---

## Requisitos previos

**PC dev:**
- Node.js 18+
- Railway CLI instalado y autenticado (`railway login`)

**PC de stream:**
- Windows 10 Pro 64 bits
- Node.js 18+
- Sunshine instalado (`C:\Program Files\Sunshine\sunshine.exe`)
- Para teclado/ratón: Visual Studio Build Tools ("Desktop development with C++"). Si falta, el vídeo funciona pero la entrada no, hasta ejecutar `cd agent; npm rebuild robotjs` y reiniciar el agente.

---

## Si algo falla

Ambos scripts son idempotentes: puedes re-ejecutarlos las veces que haga falta. Se detienen mostrando el paso exacto que falló.

Mantenimiento en el PC de stream:

```powershell
# Estado del agente, Sunshine y red
powershell -File ..\scripts\maintenance.ps1 -Action status

# Reiniciar el agente
powershell -File ..\scripts\maintenance.ps1 -Action restart-agent
```
