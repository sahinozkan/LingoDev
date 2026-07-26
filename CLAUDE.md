# LingoDev
Flutter + Firebase kelime uygulaması. Atomic Design.

## Yapı
lib/core/models, lib/core/services, lib/core/theme
lib/ui/atoms, lib/ui/molecules, lib/ui/organisms, lib/ui/views

## Kurallar
- Renkler app_colors.dart'tan (lilaPrimary #A06CD5, cardBackground #1E1B2E...)
- Font: Plus Jakarta Sans (google_fonts)
- State: StatefulWidget + setState. Yeni state kütüphanesi EKLEME.
- Yeni paket ekleme, mevcut bileşenleri (AppButton, AppInput, WordCard) kullan.