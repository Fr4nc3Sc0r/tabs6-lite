# 0. Fattibilità e ricerca

Ricerca svolta il 15 novembre 2026. Le fonti sono in [08-fonti.md](08-fonti.md).

## Risposta breve

**Sì, è tecnicamente possibile, ma è un lavoro di bring-up, non una
ricompilazione.** One UI 9 su un Tab S6 Lite 2020 è al limite di ciò che
l'hardware regge e, ad oggi, nessuno ha pubblicato un port funzionante per
questo tablet. Tre fatti rendono l'obiettivo raggiungibile:

1. **Stesso SoC del Galaxy A51**, per il quale esistono port One UI 8/8.5
   funzionanti e un target UN1CA pubblico. Vendor, kernel e partizioni sono
   quasi identici.
2. **Esiste un kernel 4.14 mantenuto per Android 17** su Exynos 9611, con la
   configurazione del tablet già pronta (`exynos9611-gta4xlwifi_defconfig`).
3. **Esiste una base One UI 9 pubblica** (fork di UN1CA) che già gestisce
   dispositivi con vendor vecchio e kernel vecchio (Exynos 990, kernel 4.19).

## Cosa NON è possibile

- **"Identico a un tablet Samsung di ultima generazione" al 100%.** Il sistema
  è quello vero di Samsung (non una imitazione), ma:
  - l'hardware è del 2020: 4 GB di RAM, Mali-G72 MP3. La stessa Samsung ha
    fermato il tablet ad Android 13. One UI 9 sarà più pesante dell'originale;
  - le funzioni **Galaxy AI on-device** richiedono NPU e RAM che il tablet non
    ha: funzioneranno al più quelle basate su cloud;
  - **Knox, Samsung Pass, Samsung Wallet, Cartella sicura** non funzionano con
    software non ufficiale (il bit Knox scatta in modo permanente al primo flash non ufficiale);
  - app bancarie e DRM Widevine L1 possono degradare (Play Integrity).
- **Garanzia che si accenda al primo tentativo.** Vedi "Rischi" sotto.

## Stato ufficiale del dispositivo

| | |
|---|---|
| Ultimo firmware ufficiale | `P610XXS7FYD1` — Android 13, One UI 5.1.1 (verificato sul server FOTA Samsung, CSC ITV) |
| Aggiornamenti ufficiali | Terminati. One UI 8 è arrivata solo al Tab S6 Lite **2024** (SM-P620/P625) |
| Kernel stock | Linux 4.14 |
| LineageOS | Supportato ufficialmente fino a 23.2 (Android 16) |

## Cosa esiste già (stato dell'arte)

| Progetto | Dispositivo | Versione | Rilevanza |
|---|---|---|---|
| UN1CA (`salvogiangri/UN1CA`) | S21, A52s, A71, A73... | One UI 8 | Sistema di build di riferimento. Nessun target Exynos 9611, nessun tablet |
| `xv2ice/UN1CA-A51` | Galaxy A51 (Exynos 9611) | One UI 8 | **Stesso SoC.** Mostra cosa serve a livello vendor su questa piattaforma |
| `kusti420/k4_un1ca` (ramo `seventeen`) | A52s, S20, S21, S23... | **One UI 9** | **Base scelta.** Contiene già la piattaforma Exynos 990 (kernel 4.19, vendor Android 13) |
| `devcore94/MonsterROM` | vari | One UI 9 | Origine del port One UI 9 usato da k4_un1ca |
| `Parbindar7/android_kernel_samsung_universal9611` | A51, M21, M31, F41, **Tab S6 Lite** | 4.14.357 | **Kernel scelto.** Ramo `lineage-24.0` = Android 17 |
| Hydrate / StrataUI / Vought / FrostSky | Galaxy A51 | One UI 8 / 8.5 | Port non open-source: confermano che One UI 8.x gira su Exynos 9611 |
| Thread XDA "One UI 8.5 port for SM-P615", "GalaxyPort (One UI 8 for SM-P610)" | Tab S6 Lite | One UI 8 | Tentativi in corso, nessuna build funzionante confermata |

## Perché questa strada e non un'altra

- **Compilare One UI dai sorgenti è impossibile**: One UI non è open source.
  Tutte le ROM "One UI" sono port di firmware ufficiali di altri dispositivi.
- **Usare il firmware del Tab S6 Lite 2024** (stesso nome commerciale) non
  aiuta: è fermo a One UI 8 ed è un hardware diverso (Exynos 1280).
- **Sorgente = Galaxy S26 (Exynos)**: è il firmware One UI 9 che la base usa per
  i dispositivi Exynos. È un telefono: la modalità tablet viene abilitata
  dichiarando il dispositivo come tablet e riusando le funzioni del firmware
  stock del tablet (S Pen, layout). Quando un tablet Exynos riceverà One UI 9
  (il Tab S10 FE oggi è ancora a One UI 8) converrà rivalutare la sorgente.

## Rischi, dal più grave

| # | Rischio | Perché | Come si affronta |
|---|---|---|---|
| 1 | **La ROM non entra** | `super` è solo 6,13 GiB, la più piccola fra tutti i dispositivi della base | EROFS compresso + debloat guidato da `tools/size_report.sh` |
| 2 | **Bootloop per il kernel** | Android 17 pretende kernel ≥ 5.10 e funzioni eBPF recenti; il tablet ha il 4.14 | Kernel con backport + "spoof" della versione per i loader BPF ([05-kernel.md](05-kernel.md)) |
| 3 | **HAL del vendor troppo vecchi** | Vendor Android 13 (HIDL) sotto un framework Android 17 | La base ha già le patch "legacy"; il resto emerge solo dai log del primo avvio |
| 4 | **Interfaccia tablet incompleta** | La sorgente è un telefono | Modulo `tablet`; da rifinire dopo il primo avvio |
| 5 | **Lentezza** | 4 GB RAM | Debloat, niente AI on-device, ZRAM |

Nessuno di questi rischi può rendere il tablet inutilizzabile in modo
permanente: finché la modalità Download funziona, il firmware stock si
ripristina con Odin ([04-installazione.md](04-installazione.md)).

## Piano B: One UI 8

Se One UI 9 si rivelasse impraticabile sul kernel 4.14, il passo indietro
naturale è One UI 8 usando come base `xv2ice/UN1CA-A51` (già provata sullo
stesso SoC). `overlay/target/gta4xlwifi` è stato scritto per essere
riutilizzabile lì con modifiche minime: i dettagli sono in
[07-stato-e-roadmap.md](07-stato-e-roadmap.md).
