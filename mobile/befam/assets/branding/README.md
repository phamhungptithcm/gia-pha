# BeFam Brand Assets

This folder contains production-ready branding exports for BeFam and the source outputs used by Android and iOS.

## Palette

- `midnight`: `#30364F`
- `midnight-light`: `#46506F`
- `cream`: `#F0F0DB`
- `sand`: `#E1D9BC`
- `mist`: `#ACBAC4`

## Files

- `logos/logo-primary.png` and `logos/logo-primary.svg`: main BeFam logo
- `logos/logo-light.png` and `logos/logo-light.svg`: logo for light surfaces
- `logos/logo-dark.png` and `logos/logo-dark.svg`: logo for dark surfaces
- `app-icon/app-icon-1024.png`: master app icon export for stores and platform resizing
- `splash/splash-logo.png`: centered splash mark and wordmark for launch screens
- `android/notification/notification-icon-96.png`: source for Android notification icon exports
- `android/adaptive/adaptive-foreground-432.png`: Android adaptive icon foreground
- `android/adaptive/adaptive-monochrome-432.png`: Android 13 monochrome icon source
- `store/google-play-feature-graphic.png`: store listing feature graphic

## Regenerate

Run:

```bash
python3 scripts/generate_brand_assets.py
```

The generator refreshes the shared branding folder plus:

- Android launcher, adaptive, splash, and notification assets in `android/app/src/main/res`
- iOS app icons and launch images in `ios/Runner/Assets.xcassets`

## Store Notes

The generated pack covers the icon and feature graphic. Live device screenshots should still be captured from the real app before production store submission.
