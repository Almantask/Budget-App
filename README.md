# Šeimos biudžetas

Flutter programėlė jums ir žmonai: **iOS**, **Android** ir web peržiūra. Bankai: **Artea**, **Revolut**, **Swedbank**, **Wise**.

## Ką moka

- Kategorizuoja operacijas (maistas, būstas, prenumeratos ir t. t.)
- Žymos **būtina** / **nebūtina**
- Filtras pagal žmogų (numatytai **Abu**), kategoriją ir žymą
- Savaitės, mėnesio, metų ir viso laikotarpio vaizdas
- Delta palyginimas su praėjusiu laikotarpiu
- **Išlaidos ir pajamos per laiką** — mėnesių ir savaičių grafikas
- **Biudžeto ribos** su įspėjimu ir viršijimu; po sinchronizacijos — pranešimas, jei riba naujai pasiekta
- **Mėnesio iššūkis** ir taupymo tikslas (XP, lygiai, ženkleliai)
- **Neįprastos išlaidos** palyginti su pastaraisiais mėnesiais
- Patarimai, kur sutaupyti, ir **didžiausia vertė** (didžiausios išlaidos, taupymo svirtys, pasikartojantys mokėjimai)
- CSV eksportas ir kiekvieno banko CSV importas
- Kartą į dieną auto-sync (app atidarius ir OS background task)

## Paleidimas

```bash
flutter pub get
flutter test
flutter run
```

Pirmą kartą įkeliami demo šeimos duomenys, kad iškart matytumėte apžvalgą. **Raktai vieni savaime demo režimo neišjungia** — kiekvieną banką reikia susieti atskirai.

## Tikri bankai (PSD2)

1. Užsiregistruokite [Enable Banking](https://enablebanking.com/) ir įkelkite RSA **sertifikatą** (`.crt`) — gausite application ID. Atsisiųskite ir **privatų raktą** `{application-id}.pem`.
2. Nustatymuose įrašykite:
   - **application ID** (tik ID, be `.pem` pabaigos)
   - visą privatų PEM raktą, kuris prasideda `-----BEGIN PRIVATE KEY-----` arba `-----BEGIN RSA PRIVATE KEY-----` — **ne** `.crt` sertifikatą
3. Enable Banking **Allowed Redirect URLs** įrašykite HTTPS callback (numatytasis):

   `https://almantask.github.io/Budget-App/enable-banking/callback.html`

   Tas pats adresas turi būti ir programėlės nustatymuose. Po merge GitHub Actions publikuoja šį puslapį į `gh-pages` — repo Settings → Pages pasirinkite šaką `gh-pages`.
4. Išsaugojus raktus, programėlė išeina iš demo sąskaitų. **Bankai** skiltyje kiekvienam bankui (Artea, Revolut, Swedbank, Wise) spauskite **Susieti tikrą banką**, patvirtinkite sutikimą banke. Callback puslapis atidarys programėlę su `code`; jei ne — įklijuokite grįžimo nuorodą. Po sėkmingo ryšio to banko demo operacijos pašalinamos.
5. Wise papildomai priima asmeninį API token.

Be teisingo application ID **ir** privataus rakto veikia tik demo sync ir CSV importas iš banko išrašų.

PSD2 sutikimai paprastai galioja ~90 dienų — tada banką reikia patvirtinti iš naujo.

## CI

Kiekvienas push / PR:

- `flutter analyze` ir `flutter test`
- Android **APK** + **AAB** artifact
- iOS **unsigned IPA** (macOS runner, `--no-codesign`)

Artifactus rasite GitHub Actions job išklotinėje. Release APK CI pasirašo debug raktu, kad failą būtų galima įsirašyti į telefoną. Store / TestFlight leidybai reikės jūsų keystore ir Apple sertifikatų.

## Struktūra

- `lib/services` — kategorijos, analitika, CSV, įžvalgos
- `lib/banks` — Enable Banking, Wise API, demo connector, kasdienis sync
- `lib/ui` — apžvalga, operacijos, įžvalgos, bankai, nustatymai
