<p align="center">
  <img src="assets/images/mascota_avatar.png" width="160" alt="Mascota de Amatista">
</p>

<h1 align="center">Amatista · Fitness App</h1>

<p align="center">
  App de entrenamiento con estilo anime hecha en <b>Flutter</b> para Android.<br>
  Protege tu perfil con <b>huella + rostro</b> y mide cada sesión con <b>podómetro, acelerómetro, giroscopio y GPS</b>.
</p>

---

## Funciones

| Componente | Qué hace en la app |
|---|---|
| **Huella dactilar** | Primer paso del desbloqueo, con el diálogo biométrico del sistema (`local_auth`). |
| **Reconocimiento facial** | Segundo paso: la cámara frontal compara la forma del rostro con la registrada (ML Kit) y pide una sonrisa como prueba de vida. No se guardan fotos. |
| **Podómetro** | Pasos acumulados de la sesión (STEP_COUNTER), con respaldo por acelerómetro. |
| **Acelerómetro** | Ejes X, Y, Z y clasificación de la intensidad: descanso, caminata o trote. |
| **Giroscopio** | Velocidad angular, orientación, inclinación y giros detectados. |
| **GPS y mapa** | Coordenadas en tiempo real y trazado de la ruta sobre OpenStreetMap (sin API key). |
| **Historial** | Cada entrenamiento se guarda en SQLite: fecha, duración, pasos, distancia, ruta y gráficas. |

**Calidad**
- Permisos en tiempo de ejecución con una explicación antes de cada diálogo: biometría, cámara, ubicación, actividad física y notificaciones.
- Batería: los sensores se liberan al pausar, al cambiar de pantalla y al pasar a segundo plano.
- Interfaz Material 3 en lila y morado, tipografía M PLUS Rounded 1c, mascota ilustrada y destellos animados.

## Estructura

```
lib/
├── app/            # MaterialApp, tema y paleta
├── features/
│   ├── auth/       # registro, huella, rostro, desbloqueo
│   ├── tracking/   # sensores, GPS y sesión en vivo
│   ├── history/    # SQLite, historial y resumen
│   ├── dashboard/  # inicio, metas semanales
│   ├── lab/        # sensores en vivo
│   ├── profile/    # perfil y seguridad
│   └── shell/      # navegación con dock flotante
└── shared/         # base de datos, mapa, gráficas, permisos, widgets
```

Cada módulo separa sus capas en `data` (modelos y repositorios), `logic` (estado con Provider) y `ui` (pantallas).

## Ejecutar

Requisitos: Flutter 3.44 o superior y un **celular Android físico** (el emulador no tiene podómetro, giroscopio ni lector de huella reales).

```bash
flutter pub get
flutter run
```

Generar el APK:

```bash
flutter build apk --release --split-per-abi
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Paquetes principales

`provider` · `sqflite` · `local_auth` · `camera` · `google_mlkit_face_detection` · `permission_handler` · `sensors_plus` · `pedometer` · `geolocator` · `flutter_map` · `fl_chart`

---

<p align="center">
  Desarrollo de Aplicaciones Móviles · Proyecto Integrador Parcial 3<br>
  Universidad Politécnica de Francisco I. Madero (UPFIM)
</p>
