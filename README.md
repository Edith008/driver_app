# Driver App (Delivery Prototype)

Aplicación Flutter enfocada en conductores de delivery: navegación hacia el restaurante, cambio de estados del viaje y entrega al cliente.

## Requisitos

- Flutter 3.x (usa `fvm` si está configurado).
- Android SDK 35.
- Cuenta de Google Cloud con **Maps SDK for Android** y **Directions API** habilitadas.

## Variables sensibles

1. Copia `.env.example` a `.env.local` y coloca tu clave real en `GOOGLE_MAPS_API_KEY` (este archivo ya está ignorado por Git).
2. Ejecuta la app con el script que inyecta la variable como `--dart-define` sin exponerla:
   ```powershell
   pwsh ./scripts/run_with_env.ps1
   ```
   - Usa `-EnvFile` si quieres otro nombre (`pwsh ./scripts/run_with_env.ps1 -EnvFile ./secrets/.env.dev`).
   - Usa `-Device` o `-Release` para pasar los flags habituales de `flutter run`.
3. Si prefieres un comando directo, obtén la clave desde tu gestor de secretos y ejecuta:
   ```bash
   flutter run --dart-define=GOOGLE_MAPS_API_KEY=TU_CLAVE
   ```
   (Asegúrate de no copiar ese comando a archivos versionados.)

## Estructura principal

```
lib/
 ├─ core/            # Configuración global (AppConfig, estilos, utils)
 ├─ services/        # Integraciones (ubicación, Directions API, backend)
 └─ features/
     ├─ splash/
     ├─ auth/
     ├─ home/
     ├─ map/         # Pantalla principal del conductor
     └─ orders/
```

`AppConfig.googleMapsApiKey` lee únicamente de `String.fromEnvironment`, por lo que la clave nunca queda hardcodeada. Lo mismo aplica para `AppConfig.backendBaseUrl`, que por defecto apunta a `https://8e88a067696a.ngrok-free.app` pero puedes sobreescribirlo con `--dart-define=BACKEND_BASE_URL=https://tu-url.ngrok-free.app` cuando lo necesites.

## Scripts útiles

```bash
pwsh ./scripts/run_with_env.ps1        # corre la app cargando la API key desde .env.local
fvm flutter pub get
fvm flutter analyze
fvm flutter test
```

## Backend

- **Login de conductor**: `POST /drivers/login`
   ```json
   { "username": "alex_driver", "password": "1234" }
   ```
   Respuesta esperada (200):
   ```json
   { "ok": true, "driverId": 7, "name": "Alex Valdez" }
   ```
- **Pedido activo**: `GET /drivers/{id}/delivery`
   ```json
   {
      "hasDelivery": true,
      "delivery": {
         "id": 42,
         "estado": "RUTA_RECOJO",
         "pickupLat": -17.78,
         "pickupLng": -63.18,
         "dropoffLat": -17.79,
         "dropoffLng": -63.18,
         "order": { "id": 155, "status": "CONFIRMADO", "total": "45.00" }
      }
   }
   ```
- **Reporte de ubicación**: `PUT /drivers/{driverId}/location`
   ```json
   { "lat": -12.06345, "lng": -77.03456 }
   ```
- **Estado del viaje**: `PATCH /drivers/{driverId}/delivery/{deliveryId}/status`
   ```http
   PATCH /drivers/7/delivery/42/status
   Content-Type: application/json

   { "status": "RUTA_ENTREGA" }
   ```
   Respuesta típica:
   ```json
   {
      "id": 42,
      "estado": "RUTA_ENTREGA",
      "pickupLat": -17.7837793056728,
      "pickupLng": -63.18175049023291,
      "dropoffLat": -17.79,
      "dropoffLng": -63.18,
      "recogidoEn": "2025-12-04T19:32:15.123Z",
      "entregadoEn": null,
      "order": {
         "id": 155,
         "status": "CONFIRMADO",
         "total": "45.00",
         "user": {
            "name": "Ana",
            "locationLat": -17.79,
            "locationLng": -63.18
         }
      }
   }
   ```
   Estados permitidos: `RUTA_RECOJO`, `ESPERA_RESTAURANTE`, `RUTA_ENTREGA`, `ESPERA_CLIENTE`, `ENTREGADO`, `CANCELADO`.
   Flujo actual en la app:
   - El pedido llega en `RUTA_RECOJO` por defecto.
   - Al detectar (<=80 m) que el conductor llegó al local, `MapScreen` envía automáticamente `ESPERA_RESTAURANTE` sin intervención del usuario.
   - El botón **Pedido recogido** dispara `RUTA_ENTREGA` y recalcula la ruta hacia el cliente.
   - Cuando la ubicación del conductor está dentro del radio del cliente, la app envía `ESPERA_CLIENTE` automáticamente.
   - En ese punto aparece **Pedido entregado**, que publica `ENTREGADO`.
   - Tras eso se muestra **Pedido finalizado**; al pulsarlo la vista del mapa se limpia y solo queda la ubicación en vivo del conductor, lista para un nuevo encargo.

El login ya alimenta `DriverSession` y, si las credenciales son correctas, se abre la `HomeScreen`. En la pestaña **Pedidos** se consulta `GET /drivers/{id}/delivery`; si existe un pedido activo, se muestra la tarjeta con botón “Ir al mapa”. El mapa recibe esa asignación, actualiza los puntos de ruta, envía la ubicación del conductor cada 10 s y reporta los cambios de estado (`ESPERA_RESTAURANTE`, `RUTA_ENTREGA`, `ESPERA_CLIENTE`, `ENTREGADO`) contra `PATCH /drivers/{driverId}/delivery/{deliveryId}/status` antes de limpiar la vista al finalizar el viaje.