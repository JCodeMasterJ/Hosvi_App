# 🧭 HOSVI APP – Guía accesible de navegación hospitalaria

**HOSVI APP** (Hospital Smart Visual Guidance) es una aplicación móvil desarrollada en **Flutter** que permite orientar a personas con discapacidad visual y visitantes dentro de entornos hospitalarios. Combina tecnologías de **geolocalización (GPS + Google Maps)**, **voz (TTS)**, **hápticos (vibración)** y **geocercas** para brindar navegación paso a paso hacia hospitales definidos en Bucaramanga y Floridablanca.

---

## 🚀 Características principales

- 🔐 **Autenticación con Firebase Auth**
  - Acceso para administradores (correo institucional)
  - Modo invitado (sin registro)
  - Opción “Recordarme” para admins

- 🗺️ **Mapas y rutas interactivas**
  - Integración con **Google Maps** y **Directions API**
  - Visualización de zonas activas (geocercas)
  - Rutas guiadas con indicaciones por voz y distancia restante

- 🎙️ **Asistencia por voz y accesibilidad**
  - Indicaciones auditivas (TTS en español)
  - Retroalimentación háptica (vibraciones)
  - Modo de alto contraste, texto e iconos escalables

- ⚙️ **Panel de administración**
  - Gestión de puntos de accesibilidad
  - Forzar recarga de zonas
  - Acceso al mapa general y vista de depuración

- ☁️ **Infraestructura en la nube**
  - Firestore para roles y configuración
  - Google Cloud para APIs de mapa y direcciones

---

## 🧩 Estructura del proyecto

