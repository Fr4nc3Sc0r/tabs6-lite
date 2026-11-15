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
| **La ROM completa non è mai stata costruita** | Nell'ambiente in cui è stato scritto il repository il download dei firmware Samsung non era consentito | Prima esecuzione di `./build.sh` o del workflow |
| Valori `[VERIFY]` di `config.sh` | Come sopra | Report di `--probe-only` |
| La ROM entra in 6,13 GiB | Dipende dal firmware reale | Prima build completa |
| **Il tablet si avvia** | Nessun test su hardware | Primo flash |
| Funzionamento di Wi-Fi, audio, fotocamera, S Pen, sensori, DeX | Idem | Dopo il primo avvio |
| Interfaccia tablet corretta partendo da un firmware da telefono | Idem | Dopo il primo avvio |

## Roadmap

### Fase A — Probe (nessun rischio per il tablet)
- [ ] Impostare il secret `TABS6_SERIAL`
- [ ] Eseguire `mode = probe`
- [ ] Portare a zero i `FAIL` e i `WARN` di `verify_target-report.md`
- [ ] Annotare qui: nome del gruppo `super`, numero di HAL a 32/64 bit,
      presenza di `portrait_data`, elenco policy SDHMS

### Fase B — Prima build completa
- [ ] `mode = rom`; risolvere gli arresti (vedi troubleshooting, Fase 0)
- [ ] Far rientrare la ROM nella `super` (`size_report.sh` → `debloat.sh`)
- [ ] Controllare `skipped_patches.txt`

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
