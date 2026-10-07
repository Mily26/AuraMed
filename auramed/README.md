# Aura Med

App de iOS (SwiftUI, iOS 17+) para recordatorios de toma de medicamentos, basada en los diseños de `../stitch_auramed_reminder` (sistema "Serene Apothecary Minimal").

## Abrir y ejecutar

1. Abre `AuraMed.xcodeproj` en Xcode.
2. En *Signing & Capabilities* elige tu equipo (Team) para instalar en tu iPhone.
3. Ejecuta en un simulador o en tu dispositivo.

Para ver la app con datos de ejemplo (solo en Debug): *Product › Scheme › Edit Scheme › Run › Arguments* y añade `-seedDemo`. Solo se cargan si el almacenamiento está vacío.

## Pantallas

- **Hoy**: saludo, cinta de días, progreso del día, tomas agrupadas en Mañana / Tarde / Noche, "Tomar ahora", "Pausar 30m", menú contextual (omitir, deshacer, editar) y tomas fuera de hora.
- **Botiquín**: búsqueda, filtros por tipo, aviso de reposición, stock con barra, reponer, pausar o eliminar.
- **Progreso**: constancia del mes, racha, ritmo semanal, desglose por tratamiento y exportación del informe en PDF.
- **Nuevo recordatorio (+)**: nombre, tipo, forma, dosis, frecuencia (diario, días fijos, a demanda), horarios, contexto de ingesta y stock.
- **Perfil** (foto): nombre, foto, permisos de notificación y recordatorios silenciosos.

## Datos locales

Todo se guarda en el iPhone con SwiftData (sin iCloud ni servidores). El nombre y la foto de perfil se guardan en UserDefaults y en Documents.

## Notificaciones

Son notificaciones locales con las acciones "Tomar ahora" y "Pausar 30 min". Se programan para los próximos 14 días, hasta el límite de iOS de 64 notificaciones pendientes. La lista se recalcula cada vez que abres la app o cambias algo, así que las tomas ya registradas no vuelven a avisar.

## Tipografías

El diseño usa **EB Garamond** y **Plus Jakarta Sans** (Google Fonts, licencia OFL). Si colocas sus archivos `.ttf` en `AuraMed/Fonts/`, se registran solas al iniciar. Si no están, la app usa la serif y la sans del sistema.
