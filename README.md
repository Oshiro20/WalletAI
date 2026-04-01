<<<<<<< HEAD
# 💰 Control Financiero - Aplicativo de Gastos

Aplicativo inteligente de control de gastos e ingresos con IA, desarrollado en Flutter.

## ✨ Características Principales

- 📱 **Multiplataforma**: Android y Web
- 🤖 **IA Integrada**: 
  - Reconocimiento de voz para registro rápido
  - OCR para escaneo de boletas
  - Categorización inteligente con Gemini AI
  - Asistente financiero conversacional
- 💾 **Offline-First**: Funciona sin internet
- 🔄 **Sincronización**: Backup automático en Google Drive
- 📊 **Análisis Avanzado**: Gráficos interactivos y predicciones
- 🔐 **Seguridad**: Base de datos encriptada, PIN/Biometría
- 💳 **Multi-Cuenta**: Gestión de múltiples cuentas financieras
- 🎯 **Metas de Ahorro**: Seguimiento de objetivos financieros
- 🔔 **Recordatorios**: Notificaciones de pagos recurrentes

## 🏗️ Arquitectura

El proyecto sigue **Clean Architecture** con separación en capas:

```
lib/
├── core/           # Constantes, tema, utilidades
├── data/           # Base de datos, modelos, repositorios
├── domain/         # Entidades, casos de uso
├── services/       # IA, sincronización, permisos
├── presentation/   # UI, pantallas, widgets
└── features/       # Funcionalidades específicas
```

## 🛠️ Stack Tecnológico

- **Framework**: Flutter 3.38.9
- **Lenguaje**: Dart 3.10.8
- **Base de Datos**: Drift (SQLite)
- **Estado**: Riverpod
- **IA**:
  - Speech-to-Text: Android Speech Recognition
  - OCR: Google ML Kit
  - NLP: Gemini 1.5 Flash
- **Sincronización**: Google Drive API
- **Navegación**: go_router

## 📦 Instalación

### Requisitos Previos

- Flutter SDK 3.x
- Android Studio (para desarrollo Android)
- Git

### Pasos

1. **Clonar el repositorio**
   ```bash
   git clone <repository-url>
   cd Aplicativo_Gastos
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Generar código de Drift**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Ejecutar la aplicación**
   ```bash
   flutter run
   ```

## 🗄️ Base de Datos

El aplicativo utiliza **Drift** (wrapper type-safe de SQLite) con 13 tablas:

- `accounts` - Cuentas financieras
- `transactions` - Transacciones (ingresos/gastos/transferencias)
- `categories` - Categorías de transacciones
- `subcategories` - Subcategorías
- `budgets` - Presupuestos por categoría
- `savings_goals` - Metas de ahorro
- `recurring_payments` - Pagos recurrentes
- `tags` - Etiquetas personalizadas
- `transaction_tags` - Relación transacciones-etiquetas
- `attachments` - Adjuntos (fotos de boletas)
- `contexts` - Contextos temporales (viajes, eventos)
- `sync_queue` - Cola de sincronización
- `settings` - Configuración de la app

## 🎨 Tema

La aplicación utiliza **Material Design 3** con:

- Modo claro y oscuro
- Colores vibrantes y modernos
- Tipografía Inter de Google Fonts
- Componentes personalizados

## 🚀 Comandos Útiles

```bash
# Instalar dependencias
flutter pub get

# Generar código (Drift)
dart run build_runner build --delete-conflicting-outputs

# Ejecutar en modo debug
flutter run

# Ejecutar en modo release
flutter run --release

# Ejecutar tests
flutter test

# Analizar código
flutter analyze

# Formatear código
dart format .

# Build APK
flutter build apk --release

# Build Web
flutter build web --release
```

## 📱 Plataformas Soportadas

- ✅ Android (API 21+)
- ✅ Web (PWA)
- ⏳ iOS (futuro)
- ⏳ Windows Desktop (futuro)

## 🔑 Configuración de APIs

### Gemini AI

1. Obtén una API key de [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Configúrala en la app (primera ejecución)

### Google Drive

1. Crea un proyecto en [Google Cloud Console](https://console.cloud.google.com/)
2. Habilita Google Drive API
3. Configura OAuth 2.0
4. Descarga el archivo de credenciales

## 📚 Documentación

- [Arquitectura del Proyecto](docs/architecture.md)
- [Esquema de Base de Datos](docs/database_schema.md)
- [Flujos de Usuario](docs/user_flows.md)
- [Decisiones Técnicas](docs/technical_decisions.md)

## 🧪 Testing

```bash
# Unit tests
flutter test test/unit

# Widget tests
flutter test test/widget

# Integration tests
flutter test integration_test
```

## 📄 Licencia

Este proyecto es privado y de uso personal.

## 👨‍💻 Autor

Desarrollado con ❤️ por [Tu Nombre]

## 🗺️ Roadmap

### Versión 1.0 (MVP)
- [x] Configuración inicial del proyecto
- [x] Base de datos completa
- [ ] Pantallas principales (Home, Transacciones, Cuentas)
- [ ] Registro manual de transacciones
- [ ] Análisis básico

### Versión 1.1
- [ ] Registro por voz
- [ ] OCR de boletas
- [ ] Categorización con IA

### Versión 1.2
- [ ] Sincronización con Google Drive
- [ ] Metas de ahorro
- [ ] Presupuestos

### Versión 2.0
- [ ] Asistente financiero conversacional
- [ ] Predicciones con IA
- [ ] Modo viaje
- [ ] Versión iOS

---

**Estado del Proyecto**: 🚧 En Desarrollo Activo
=======
# WalletAI
Aplicativo para control de finanzas personales
>>>>>>> db436bba0a1ecfbd21d3412d174739a01fd50e0f
