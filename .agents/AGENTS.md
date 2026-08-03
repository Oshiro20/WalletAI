# AGENTS.md - Reglas y Directivas del Proyecto WalletAI

## Reglas de Lanzamiento y Publicación a Producción
1. **Paso a Paso Obligatorio de Release**:
   - **Paso 1**: Actualizar el número de versión en `pubspec.yaml` (ej. `version: X.Y.Z+N`) ANTES de iniciar cualquier compilación.
   - **Paso 2**: Ejecutar `flutter clean` para purgar todas las versiones y cachés anteriores en `build/` y `android/app/build`.
   - **Paso 3**: Ejecutar `flutter build apk --release` y ESPERAR a que la compilación termine al 100% de forma síncrona.
   - **Paso 4**: Confirmar que el archivo `build/app/outputs/flutter-apk/app-release.apk` fue generado en ese mismo instante con el nuevo número de versión.
   - **Paso 5**: ÚNICAMENTE tras completar los pasos anteriores, crear el commit, el tag de Git y subir el release a GitHub (`gh release create`). NUNCA lanzar la creación del release en GitHub en paralelo mientras la compilación siga ejecutándose en segundo plano.

## Reglas de Idioma y Enfoque
- Responder siempre en español.
- Mantener el enfoque exclusivo en el proyecto solicitado por el usuario.
