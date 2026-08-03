# F-Droid Compliance Notes

## google_fonts dependency

The `google_fonts` package (v8.x) is used for Inter typography. In v8.x, fonts are
**bundled at compile time** from the pub package assets rather than fetched over the
network at runtime, so no Google CDN call is made on the user device.

Reference: https://pub.dev/packages/google_fonts#-readme-tab-

If F-Droid reviewers prefer fully bundled fonts with no google_fonts dependency at all,
the font files can be downloaded from Google Fonts (OFL licensed) and bundled under
`assets/fonts/` with a pubspec declaration, then replace `GoogleFonts.interTextTheme`
with a `TextTheme` referencing the local font family.

## carrier_info dependency

`carrier_info` uses Android TelephonyManager API (AOSP). No proprietary SDK dependency.

## No Firebase, GMS, or proprietary SDKs

No Firebase, Google Play Services (GMS), Google Analytics, AdMob, Crashlytics,
or any other proprietary Google/non-FOSS SDK is present in this project.

All dependencies are available on pub.dev and resolve to MIT, BSD, or Apache-2.0 licensed packages.
