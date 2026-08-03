# 💰 Control Financiero - WalletAI (MyLifeOS Finance)

> [!IMPORTANT]
> **Estado del Proyecto**: 🟢 ESTABLE / MANTENIMIENTO
> **Versión Actual**: v1.3.3
> **Protocolo**: Antigravity Structural Standard 2026 v2.1

Aplicativo inteligente de control de gastos e ingresos con IA integrada (Gemini), desarrollado en Flutter con enfoque Offline-First.

## ✨ Características Principales

- 📱 **Multiplataforma**: Android y Web (PWA).
- 🤖 **IA Avanzada (Gemini 1.5 Flash)**:
  - Registro por voz y procesamiento de lenguaje natural.
  - OCR inteligente para escaneo de boletas y comprobantes.
  - Categorización automática y sugerencias predictivas.
- 🔄 **Sincronización**: Backup automático en Google Drive y soporte Supabase.
- 📊 **Análisis**: Dashboards dinámicos, predicciones de flujo de caja y gestión de presupuestos.
- 🔐 **Seguridad**: Cifrado local, autenticación biométrica y gestión de sesiones.

## 🏗️ Mapa de Arquitectura (Clean Architecture)

```text
Aplicativo_Gastos/
├── android/ ios/ web/   # Plataformas nativas
├── builds/              # Histórico de APKs (Límite 3 versiones)
├── docs/                # Documentación del proyecto y reportes de análisis
├── lib/
│   ├── core/            # Configuración, temas, utilidades y constantes
│   ├── data/            # Fuentes de datos (Drift DB, Supabase, API)
│   ├── domain/          # Entidades y Casos de Uso (Lógica de Negocio)
│   ├── presentation/    # Bloques de UI, Pantallas y Gestores de Estado (Riverpod)
│   └── l10n/            # Internacionalización (Soporte Multi-idioma)
├── scripts/             # Herramientas de mantenimiento y testeo rápido
├── test/                # Tests unitarios, de widget e integración
└── assets/              # Recursos estáticos (Iconos, fuentes, animaciones)
```

## 🔐 Configuración (Environment)

El proyecto requiere un archivo `.env` en la raíz con las siguientes claves:

```env
GEMINI_API_KEY=tu_api_key_aqui
SUPABASE_URL=tu_url_de_supabase
SUPABASE_ANON_KEY=tu_anon_key_aqui
DRIVE_CLIENT_ID=google_drive_client_id
```

## 🛠️ Stack Tecnológico

- **Framework**: Flutter 3.x / Dart 3.x
- **Persistencia**: Drift (SQLite) & Supabase
- **Estado**: Riverpod (Functional approach)
- **Navegación**: GoRouter
- **IA**: Google Generative AI (Gemini) & ML Kit

## 🚀 Comandos de Desarrollo

```bash
# Iniciar ambiente
flutter pub get

# Generación de código (Drift, Freezed, etc)
dart run build_runner build --delete-conflicting-outputs

# Generación de localización
flutter gen-l10n

# Compilación de producción
flutter build apk --release
```

## 🗺️ Roadmap Actualizado

- [x] **v1.0 - Core**: Estructura de DB, gestión de cuentas y transacciones.
- [x] **v1.1 - AI Integration**: Registro por voz y categorización básica.
- [x] **v1.2 - Cloud Sync**: Sincronización con Google Drive y Supabase.
- [x] **v1.3 - UI Redesign**: Implementación total de Material 3 "Indigo Vault".
- [ ] **v2.0 - Predictive**: Análisis predictivo avanzado y multi-usuario.

---
Desarrollado según el **Project Governance 2026**. Mantener siempre la raíz libre de archivos temporales.
