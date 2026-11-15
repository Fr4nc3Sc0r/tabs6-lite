# 2. Architettura del port

## Da dove viene ogni pezzo della ROM

```
                  Galaxy S26 Exynos (SM-S942B)            Tab S6 Lite (SM-P610)
                  One UI 9 / Android 17                   One UI 5.1.1 / Android 13
                  ───────────────────────────             ─────────────────────────
  /system    ◄──  system  (+ system_ext dentro)
  /product   ◄──  product
  /odm       ◄──  odm (ripulito: manifest e permessi rimossi)
  /vendor    ◄──────────────────────────────────────────  vendor (driver, HAL, firmware)
  boot.img   ◄──────────────────────────────────────────  ramdisk + DTB + header
             ◄──  kernel 4.14.357 compilato dai sorgenti (albero universal9611)
  dtbo.img   ◄──────────────────────────────────────────  dtbo
  vbmeta.img ◄──────────────────────────────────────────  vbmeta con verifica disattivata
  recovery, bootloader, efs, userdata: NON toccati dallo zip
```

Il principio è quello di Project Treble: il **vendor** (tutto ciò che parla con
l'hardware) resta quello del tablet; il **sistema** viene da un dispositivo
nuovo. Dove l'interfaccia fra i due è cambiata in quattro versioni di Android,
servono patch.

## La base

`setup.sh` scarica in `./un1ca` il repository
[`kusti420/k4_un1ca`](https://github.com/kusti420/k4_un1ca), ramo `seventeen`,
al commit `bf0d0240887c28517e08304fcf1d2bb536014f16` (9 ottobre 2026).

Perché questa base:

- è UN1CA (il sistema di build richiesto) portato a **One UI 9**;
- definisce la sorgente Exynos (`unica/configs/essi.sh`): `SM-S942B`, SDK 37;
- contiene `platform/exynos990`: dispositivi con **kernel 4.19 e vendor
  Android 13**, cioè lo stesso problema del tablet, già affrontato;
- le patch generiche `unica/patches/legacy` gestiscono vendor fino ad API 33
  (HAL luci, face, sdFAT, usb_notify, eBPF hotspot...);
- `unica/patches/vndk` aggiunge l'APEX VNDK 33 che i binari del vendor richiedono.

Il commit è **fissato**: una base che cambia sotto i piedi renderebbe i
problemi non riproducibili. Per aggiornarla vedi "Aggiornare la base" in fondo.

## Cosa aggiunge questo repository

### `overlay/platform/exynos9611/` — la piattaforma

| File | Scopo |
|---|---|
| `config.sh` | Livelli API, partizioni dinamiche, EROFS, funzioni Wi-Fi comuni ai 9611 |
| `installer/recovery.fstab` | Nomi delle partizioni per lo script di installazione |
| `debloat.sh`, `sff.sh` | Rimozioni e floating feature di piattaforma |
| `patches/kernel/` | **Compila il kernel** e lo inserisce nella boot stock ([05-kernel.md](05-kernel.md)) |

### `overlay/target/gta4xlwifi/` — il tablet

| File | Scopo |
|---|---|
| `config.sh` | Identità, firmware stock, dimensioni partizioni, funzioni hardware |
| `sff.sh` | Override delle floating feature (quasi vuoto: il grosso arriva da stock) |
| `debloat.sh` | App da rimuovere per rientrare nei 6,13 GiB |
| `patches/tablet/` | `ro.build.characteristics=tablet`; pulizia di `/odm` del telefono |
| `patches/storage/` | Rimuove la cifratura di `/data` dall'fstab (vedi sotto) |
| `installer/` | Aggiunge allo zip la `vbmeta` con verifica disattivata |

### `tools/`

| Script | Scopo |
|---|---|
| `gen_target_from_stock.sh` | Copia nel target i file dispositivo dal firmware stock |
| `verify_target.sh` | Confronta la configurazione con il firmware stock, produce un report |
| `size_report.sh` | Elenca cosa occupa spazio, per il debloat |
| `build_kernel.sh` | Compila solo il kernel, senza firmware Samsung |

## Ordine di esecuzione di una build

1. `setup.sh` — base al commit fissato + overlay.
2. `source buildenv.sh gta4xlwifi` — genera `out/config.sh` unendo
   `target/gta4xlwifi/config.sh`, `platform/exynos9611/config.sh` e
   `unica/configs/essi.sh`.
3. `build_dependencies` — compila gli strumenti (erofs-utils, lpmake, apktool...).
4. `download_fw` / `extract_fw` — firmware S26 e P610 dai server Samsung.
5. `gen_target_from_stock.sh`, `verify_target.sh` — file e controlli dal firmware reale.
6. `make_rom`:
   1. crea la work dir (system/product/odm dalla sorgente, vendor e kernel dal tablet);
   2. applica `platform/exynos9611/patches` (**kernel**);
   3. applica `target/gta4xlwifi/patches` (`storage`, `tablet`);
   4. applica `unica/patches` (floating feature, legacy, vintf, vndk, debloat...);
   5. applica `unica/mods` (funzioni extra di UN1CA);
   6. ricompila APK/JAR modificati, crea le immagini EROFS e lo zip.

## Scelte progettuali e motivazioni

**EROFS per tutte le partizioni.** È il default della base ed è ciò che permette
di stare in 6,13 GiB. Il kernel scelto ha `CONFIG_EROFS_FS_ZIP=y` e l'fstab del
tablet elenca già `erofs` per ogni partizione logica.

**Si sostituisce solo l'`Image` del kernel.** Ramdisk, DTB, cmdline, offset e
livello di patch della boot stock restano. Motivi: il ramdisk contiene l'fstab
di primo stadio giusto per il tablet; il DTB stock descrive l'hardware esatto;
il livello di patch è legato alle chiavi del Keymaster.

**Cifratura di `/data` rimossa (default).** Entrambi i port di riferimento
(A51 ed Exynos 990) la rimuovono: le chiavi del Keymaster 4 nel TEE sono legate
a versione e patch level del sistema stock, e un sistema Android 17 sopra un TEE
Android 13 non dà garanzie di poterle sbloccare (risultato: bootloop o "dati
corrotti"). **Conseguenza: i dati sul tablet non sono cifrati.** Per provare a
mantenerla: `TABS6_KEEP_ENCRYPTION=true ./build.sh`.

**`vbmeta` con verifica disattivata dentro lo zip.** L'fstab stock chiede al
primo stadio di verificare le partizioni contro `vbmeta`; avendole ricostruite,
la verifica va disattivata. Metterla nello zip evita un passaggio manuale con Odin.

**Policy termica generica (`ssrm_default`).** Quella del tablet è cifrata dentro
l'app SDHMS stock e non è estraibile automaticamente. Effetto: i limiti termici
software sono quelli generici della base. La protezione termica del kernel
(driver TMU) resta attiva e indipendente.

**Nessun dato personale nel repository.** Il numero di serie passa solo da
variabile d'ambiente/secret; `.gitignore` esclude immagini e firmware.

## Aggiornare la base

```bash
BASE_COMMIT=<nuovo sha> ./setup.sh --force
```

Poi aggiorna il default in `setup.sh` solo dopo una build riuscita. Controlla
in particolare: `scripts/internal/gen_config_file.sh` (nuove variabili
`TARGET_*` obbligatorie), `unica/configs/essi.sh` (nuova sorgente),
`unica/patches/vndk` e `legacy`.
