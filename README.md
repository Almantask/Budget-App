# Šeimos biudžetas

Flutter programėlė jums ir žmonai: **iOS**, **Android** ir web peržiūra. Bankai: **Artea**, **Revolut**, **Swedbank**, **Wise**.

## Ką moka

- Kategorizuoja operacijas (maistas, būstas, prenumeratos ir t. t.)
- Žymos **būtina** / **nebūtina**
- Filtras pagal žmogų (numatytai **Abu**), kategoriją ir žymą
- Savaitės, mėnesio, metų ir viso laikotarpio vaizdas
- Delta palyginimas su praėjusiu laikotarpiu
- Patarimai, kur sutaupyti, ir **didžiausia vertė** (didžiausios išlaidos, taupymo svirtys, pasikartojantys mokėjimai)
- CSV eksportas ir kiekvieno banko CSV importas
- Kartą į dieną auto-sync (app atidarius ir OS background task)

## Paleidimas

```bash
flutter pub get
flutter test
flutter run
```

Pirmą kartą įkeliami demo šeimos duomenys, kad iškart matytumėte apžvalgą.

## Tikri bankai (PSD2)

1. Susikurkite nemokamą [GoCardless Bank Account Data](https://bankaccountdata.gocardless.com/) paskyrą.
2. Nustatymuose įrašykite `secret_id` ir `secret_key` — jie lieka įrenginyje.
3. Bankų skiltyje spauskite **Susieti per Open Banking**.
4. Wise papildomai priima asmeninį API token.

Be raktų veikia demo sync ir CSV importas iš banko išrašų.

PSD2 sutikimai paprastai galioja ~90 dienų — tada banką reikia patvirtinti iš naujo.

## CI

Kiekvienas push / PR:

- `flutter analyze` ir `flutter test`
- Android **APK** + **AAB** artifact
- iOS **unsigned IPA** (macOS runner, `--no-codesign`)

Artifactus rasite GitHub Actions job išklotinėje. Release APK CI pasirašo debug raktu, kad failą būtų galima įsirašyti į telefoną. Store / TestFlight leidybai reikės jūsų keystore ir Apple sertifikatų.

## Struktūra

- `lib/services` — kategorijos, analitika, CSV, įžvalgos
- `lib/banks` — GoCardless, Wise API, demo connector, kasdienis sync
- `lib/ui` — apžvalga, operacijos, įžvalgos, bankai, nustatymai
