# 7. Stato e roadmap

Documento vivo: aggiornalo a ogni tentativo. È la memoria del progetto.

## Stato al 15 novembre 2026

### Verificato

| Cosa | Come |
|---|---|
| Ultimo firmware stock SM-P610 = `P610XXS7FYD1` (Android 13) | Interrogazione del server FOTA Samsung |
| Galaxy S26 Exynos (`SM-S942B`) ha One UI 9 stabile (`S942BXXS6BZK1`, Android 17) | Server FOTA Samsung |
| Il kernel fissato compila per `gta4xlwifi` | Compilato con clang 18.1.3: `Linux version 4.14.357`, `Image` 37 974 032 byte |
| Il kernel ha capability fino a 40, spoof `uname` per i loader BPF, backport eBPF (ringbuf, BTF, trampoline...), EROFS+zip, binderfs, PSI, userfaultfd, sdFAT, usb_notify | Lettura dei sorgenti e del `.config` generato |
| La patch `0001` si applica e compila; i due parametri finiscono nel kernel | Build di prova |
| Il modulo kernel ricompone la boot mantenendo ramdisk, DTB, offset, header v2 identici e aggiunge cmdline e trailer | Prova con una boot image di test: ramdisk e DTB identici byte per byte |
| La modifica dell'fstab rimuove solo i flag di cifratura | Provata sull'fstab del tablet (da LineageOS) |
| Sintassi di tutti gli script e dei workflow | `bash -n`, parser YAML |
| Dimensioni delle partizioni, parametri della boot, combinazioni di tasti | Device tree e wiki LineageOS |

### NON verificato (serve il firmware stock e/o il tablet)

| Cosa | Perché | Quando si saprà |
|---|---|---|
| I valori `[VERIFY]` di `config.sh` che il probe non controlla | Il probe non li può controllare: vedi attività aperta 1 | Decompilazione di `framework.jar`/`services.jar` stock |
| **Il tablet si avvia** | Nessun test su hardware | Primo flash |
| Funzionamento di Wi-Fi, audio, fotocamera, S Pen, sensori, DeX | Idem | Dopo il primo avvio |
| Interfaccia tablet corretta partendo da un firmware da telefono | Idem | Dopo il primo avvio |

## Roadmap

### Fase A — Probe (nessun rischio per il tablet) — completata il 15 novembre 2026
- [x] Seriale fornito (probe eseguito in locale; il secret `TABS6_SERIAL` serve solo per GitHub Actions)
- [x] Eseguire il probe (`./build.sh --probe-only`)
- [x] Portare a zero i `FAIL` e i `WARN` di `verify_target-report.md` (0 FAIL, 0 WARN)
- [x] Risultati del probe sul firmware stock `P610XXS7FYD1/P610OXM7FYD1`:
  - gruppo `super`: `group_basic` (6 580 862 976 byte; `super` 6 585 057 280), partizioni
    logiche `system vendor product odm`
  - HAL in `/vendor/bin/hw`: 39 a 64 bit, 5 a 32 bit (vedi attività aperta 3)
  - `cameradata/portrait_data`: presente (l'attività aperta 2 non serve)
  - policy SIOP stock: `siop_gta4xl_exynos9610`; l'elenco delle policy SDHMS non è
    stato estratto (richiede di decompilare l'app SDHMS)
  - boot: header v2, patch level 2025-04, nessun modulo kernel nel vendor
  - corretti in `config.sh`: luminosità automatica `3` → `2`, RecordAlive `none` → `07010`;
    doppio altoparlante confermato `true` da `AUDIO_NUMBER_OF_SPEAKER=2` (il firmware
    non ha più la voce `AUDIO_SUPPORT_DUAL_SPEAKER`)

### Fase B — Prima build completa — completata il 15 novembre 2026
- [x] Build completa (`./build.sh`): zip flashabile prodotto, **mai flashato**
- [x] Far rientrare la ROM nella `super`: 6 240 035 712 byte su 6 580 862 976
      (margine di circa 325 MiB prima delle patch a 32 bit, vedi sotto). Ottenuto con:
  - sfondi video dell'S26 sostituiti dalle immagini fisse (805 MB, `patches/wallpaper`)
  - debloat: AOD, AR Emoji, Bixby e servizi vocali collegati (`debloat.sh`)
  - EROFS con cluster da 64 KiB (`-C 65536`), circa 420 MiB in meno su `system`
- [x] `skipped_patches.txt`: 2 patch saltate, entrambe della base e non del tablet
  - `mdnie/hdr/api37/SecSettings.apk/0001-Disable-HDR-Settings.patch`: non si applica
    al firmware `S942BXXS6BZK1`. Possibile effetto: voci HDR visibili nelle Impostazioni
  - `mdnie/hw/services.jar/0001-Disable-HW-mDNIe.patch`: rinviata dalla base

Correzioni alla base applicate da `setup.sh` (ognuna è commentata lì): reset IMEI
nel download, ramo "nessun eSE" per sorgente GEMALTO, HAL volto AIDL, patch `netd`
per l'hotspot su kernel 4.14, lettore di impronte `none`, metodo della frequenza
predefinita, Wi-Fi 6 → Wi-Fi 5, matrice FCM 4, firma di Samsung Internet, metodo
ASKS spostato, modelli Single Take assenti nel vendor, cluster EROFS.

**Controlli statici sulle immagini costruite** (non esiste un emulatore di questo
hardware: sono l'unica verifica possibile prima del flash). Hanno trovato problemi
che avrebbero impedito l'avvio, risolti con due patch di piattaforma:

- `patches/__desixtification`: il sistema S26 è solo a 64 bit, il vendor ha 5 servizi
  a 32 bit (audio, fotocamera, OMX, Widevine, CAS) e chiedeva `zygote64_32`. Aggiunti
  linker, bionic e `/system/lib` a 32 bit (prebuilt `ichthys32` della base, stessa
  build AOSP `CP2A.260605.016` del sistema); zygote solo a 64 bit. Verificato: i 71
  programmi e plugin a 32 bit del vendor risolvono tutte le dipendenze e dal sistema
  usano solo librerie LLNDK
- `patches/android17_compat`: `/vendor/ueventd.rc` in posizione non più letta,
  etichetta di `/dev/ion`, `mremap` nella policy seccomp del codec, controller cgroup
  `sfreezer` assente nel kernel, porta di tracing vsock, `rkp_only`, librerie client
  HIDL di engmode e vaultkeeper dal firmware stock

Entrambe eseguono le implementazioni che la base ha per `a52sxq` (stesso tipo di
vendor vecchio). Le circa 45 patch di quel target sono un buon elenco di controllo
per i problemi che compariranno dopo l'avvio.

Risultano a posto: VNDK 33, `hwservicemanager`, mappature SELinux 33.0, fstab EROFS
nella ramdisk e nel vendor. Non verificati: VINTF completo (manca `checkvintf`),
regole SELinux, proprietà del vendor che `init` di Android 17 può rifiutare.

Con queste patch il sistema occupa 6 302 744 576 byte su 6 580 862 976 (margine di
circa 265 MiB).

**Da verificare al primo avvio** (scelte fatte senza poterle provare):
- vendor di livello FCM 4 sotto Android 17: la build passa, l'avvio non è garantito
- i 5 HAL a 32 bit del vendor: dipendenze verificate, esecuzione da provare
- librerie stock di engmode/vaultkeeper sotto One UI 9 (engmode: compatibilità non dimostrata)
- patch binaria di `netd` scritta per questo port (hotspot)
- 6 GHz disattivato nel framework; possibili voci Wi-Fi 6 residue nelle Impostazioni
- `TARGET_FINGERPRINT_CONFIG_SENSOR="none"`: se sbagliato, voce impronte non funzionante
- file Single Take / AR Emoji vuoti; AOD rimosso dalle floating feature
- prestazioni di lettura con cluster EROFS da 64 KiB (ripiego: 16 KiB + altro debloat)

### Fase C — Primo avvio
- [ ] **Prima di flashare**: salvare da stock `getprop`, `dmesg`, `lshal`
- [ ] Scaricare il firmware stock completo per il ripristino
- [ ] Flash, raccolta log, correzione (troubleshooting, Fasi 2–4)
- [ ] Obiettivo: arrivare alla configurazione iniziale

### Fase D — Hardware
- [ ] Wi-Fi · Bluetooth · audio (2 altoparlanti, jack, microfoni) · fotocamere
- [ ] S Pen (pressione, hover, Air Command) · rotazione · luminosità · GPS
- [ ] Ricarica · microSD · USB (MTP, OTG) · sospensione/riattivazione

### Fase E — Esperienza tablet
- [ ] Taskbar, schermo diviso, layout a due pannelli nelle Impostazioni
- [ ] DeX · tastiera Book Cover
- [ ] Rimuovere ciò che è solo da telefono (dialer, SIM) **senza** rompere il framework
- [ ] Prestazioni: debloat, ZRAM, animazioni

### Fase F — Rifinitura
- [ ] Policy termica del tablet (oggi generica `ssrm_default`)
- [ ] Valutare il ripristino della cifratura (`TABS6_KEEP_ENCRYPTION`)
- [ ] BTF nel kernel
- [ ] Rivalutare la sorgente quando un tablet Exynos riceverà One UI 9

## Attività aperte note

1. **Valori non verificabili automaticamente** (`config.sh`): richiedono di
   decompilare `framework.jar`/`services.jar` del firmware stock seguendo le
   istruzioni nei commenti di `un1ca/scripts/internal/gen_config_file.sh`:
   `TARGET_FINGERPRINT_CONFIG_SENSOR` (oggi `none`),
   `TARGET_LCD_CONFIG_COLOR_WEAKNESS_SOLUTION`, `TARGET_CAMERA_SUPPORT_MASS_APP_FLAVOR`,
   `TARGET_CAMERA_SUPPORT_SDK_SERVICE`, `TARGET_BLUETOOTH_SUPPORT_A2DPSINK_PROFILE`,
   `TARGET_RIL_SIM_CONFIG_MULTISIM_TRAYCOUNT`.
2. **`portrait_data`**: se assente nel firmware del tablet la base si ferma;
   serve una patch alla base applicata da `setup.sh`.
3. **Userspace a 32 bit**: se la sorgente S26 è solo a 64 bit e il vendor ha
   HAL a 32 bit, serve l'equivalente di `__desixtification`.
4. **Sorgente telefono → tablet**: possibili app mancanti (es. componenti S Pen)
   da prendere da un firmware tablet One UI 9 tramite `SOURCE_EXTRA_FIRMWARES`.
5. **Kernel LineageOS sotto One UI**: verificare i nodi sysfs Samsung usati dal
   framework One UI (mDNIe, `sec_*`, HDM).

## Piano B — One UI 8

Se la Fase C non converge:

1. Base: `BASE_REPO=https://github.com/xv2ice/UN1CA-A51.git`, ramo `a51`
   (contiene già `platform/exynos9611` e la sorgente One UI 8 da Galaxy S22).
2. Il target `gta4xlwifi` si riusa; differenze da gestire:
   - quella base ha una propria `platform/exynos9611/config.sh` (da fondere con
     la nostra, che `setup.sh` oggi sovrascrive);
   - nomi di alcune variabili (`TARGET_AUDIO_SUPPORT_VIRTUAL_VIBRATION` invece
     di `..._SOUND`);
   - le patch del vendor di `target/a51` sono per il telefono: **non** copiarle
     alla cieca (audio policy e RIL sono dell'A51).
3. Kernel: stesso albero, ramo `lineage-23.2` (Android 16).

One UI 8 su Exynos 9611 è dimostrata funzionante da più port per A51: è la
strada con più probabilità di successo se l'obiettivo è un sistema usabile
prima possibile, a scapito dell'ultima versione.

## Diario dei tentativi

Aggiungi una riga per ogni build/flash.

| Data | Commit | Build | Esito | Fase raggiunta | Note / log |
|---|---|---|---|---|---|
| 2026-11-15 | iniziale | solo kernel | ok | — | Kernel 4.14.357 compilato, modulo boot provato con immagine di test |
| 2026-11-15 | cfd0c90 + correzioni | probe | ok | Fase A | Firmware S942BXXS6BZK1 e P610XXS7FYD1 scaricati ed estratti; verifica 0 FAIL / 0 WARN. Corretti: dipendenze host mancanti in docs/03, identità git in `build.sh`, IMEI non azzerato in `download_fw.sh` della base (FUS 408) |
| 2026-11-15 | Fase B + controlli statici | ROM completa | ok | zip prodotto | `UN1CA_4.0.0-bf0d024-dirty_20261115_gta4xlwifi-sign.zip`, 5,44 GB; OS 6,30 GB su 6,58 GB. 13 arresti di build risolti e 2 patch nate dai controlli statici (vedi Fase B). Non flashato |
