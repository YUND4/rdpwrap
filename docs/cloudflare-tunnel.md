# Acceso remoto RDP vía Cloudflare Tunnel

Guía para exponer el RDP de este equipo a Internet de forma segura, sin abrir
puertos en el router, usando Cloudflare Tunnel (`cloudflared`).

## ¿Es seguro cambiar los nameservers en Amazon? — Sí, con revisión previa

El miedo es comprensible pero el proceso es **reversible y sin downtime** si se
hace en este orden:

1. **Agrega el dominio en Cloudflare primero** (dash.cloudflare.com → Add site → Free).
   Cloudflare **escanea e importa automáticamente** tus registros DNS actuales de Route 53.
2. **Revisa los registros importados** en Cloudflare → DNS → Records. Verifica
   especialmente:
   - `A` / `AAAA` / `CNAME` (sitios web, APIs)
   - `MX` (correo — si usas el dominio para email, esto es crítico)
   - `TXT` (verificaciones de Google, SPF, DKIM)
   Compara con lo que tengas en Route 53 → Hosted zones.
3. **Solo cuando los registros coincidan**, cambia los NS en AWS:
   - Si el dominio está **registrado en AWS** (Route 53 → Registered domains):
     cambia los name servers a los 2 que te asignó Cloudflare (ej. `lara.ns.cloudflare.com`).
   - Tu hosted zone de Route 53 **no se borra**: puedes volver a los NS de AWS
     cuando quieras. El cambio es 100% reversible.
4. Propagación: minutos a ~24h. Cloudflare te avisa por email cuando el dominio
   queda "Active". No hay caída: los resolvers consultan viejos y nuevos NS en
   paralelo y ambos responden lo mismo (si el paso 2 se hizo bien).

**Lo único que NO debes hacer**: borrar la hosted zone de Route 53 o cambiar los
NS antes de verificar los registros en Cloudflare.

## Arquitectura resultante

```
Cliente RDP (laptop, celular)
   │  mstsc → localhost:3389
   ▼
cloudflared access tcp --hostname rdp.tudominio.com --url localhost:3389   (en el cliente)
   │  TLS saliente (sin puertos abiertos)
   ▼
Cloudflare edge
   │  tunnel cifrado
   ▼
cloudflared (servicio en este equipo) → localhost:3389 → RDP Wrapper
```

Ventajas: no se expone 3389 a Internet (cero escaneos de bots), TLS de Cloudflare,
y opcionalmente **Cloudflare Access** (login con email/OTP antes de llegar al RDP).

## Pasos

### 1. Login (una sola vez, abre el navegador)

```powershell
cloudflared tunnel login
```
Esto abre el navegador para elegir tu dominio y descarga el `cert.pem` a
`%USERPROFILE%\.cloudflared\`.

### 2. Crear el tunnel

```powershell
cloudflared tunnel create rdp-server
```
Anota el **Tunnel ID** y la ruta del archivo JSON de credenciales que imprime.

### 3. Configurar el tunnel

Crear `%USERPROFILE%\.cloudflared\config.yml`:

```yaml
tunnel: <TUNNEL_ID>
credentials-file: C:\Users\<tu-usuario>\.cloudflared\<TUNNEL_ID>.json

ingress:
  - hostname: rdp.tudominio.com
    service: tcp://localhost:3389
  - service: http_status:404
```

### 4. DNS: apuntar el subdominio al tunnel

```powershell
cloudflared tunnel route dns rdp-server rdp.tudominio.com
```

### 5. Instalar como servicio (arranca con Windows)

```powershell
cloudflared service install
```

### 6. Desde el equipo cliente (el que se conecta)

```powershell
# Una sola vez: instalar cloudflared tambien en el cliente
winget install Cloudflare.cloudflared

# Cada conexion: abrir el puente local (dejar corriendo)
cloudflared access tcp --hostname rdp.tudominio.com --url localhost:3389

# En otra ventana: conectar el .rdp a localhost
mstsc rdp-EQUIPO.rdp   # con full address editado a localhost:3389
```

### 7. (Recomendado) Cloudflare Access: login previo por email

En el dashboard: Zero Trust → Access → Applications → Add → Self-hosted,
hostname `rdp.tudominio.com`, política "Emails" con tu correo. Así, aunque
alguien conozca el subdominio, Cloudflare le exige autenticación antes de
tocar el RDP. **Muy recomendado** para RDP.

## Alternativa sin cambiar NS (prueba rápida)

```powershell
cloudflared tunnel --url tcp://localhost:3389
```
Genera una URL temporal `*.trycloudflare.com` sin cuenta ni dominio. Sirve para
probar hoy mismo; no es estable para uso permanente (la URL cambia en cada ejecución).
