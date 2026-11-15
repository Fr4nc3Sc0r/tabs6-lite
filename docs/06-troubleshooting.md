# 6. Risoluzione dei problemi

Organizzato per **fase**: individua fin dove arriva il tablet e vai alla
sezione corrispondente. Regola generale: **prima i log, poi le modifiche**.
Cambiare una cosa alla volta e annotare l'esito in
[07-stato-e-roadmap.md](07-stato-e-roadmap.md).

- [Fase 0 — La build non termina](#fase-0--la-build-non-termina)
- [Fase 1 — Il flash fallisce](#fase-1--il-flash-fallisce)
- [Fase 2 — Non supera il logo Samsung](#fase-2--non-supera-il-logo-samsung)
- [Fase 3 — Riavvio continuo prima dell'animazione](#fase-3--riavvio-continuo-prima-dellanimazione)
- [Fase 4 — Bloccato o in loop sull'animazione di avvio](#fase-4--bloccato-o-in-loop-sullanimazione-di-avvio)
- [Fase 5 — Si avvia ma qualcosa non funziona](#fase-5--si-avvia-ma-qualcosa-non-funziona)
- [Come raccogliere i log](#come-raccogliere-i-log)

---

## Fase 0 — La build non termina

Log: `un1ca/out/target/gta4xlwifi/<comando>-<data>.log` (su Actions: artifact `reports-N`).

### `TABS6_SERIAL is not set` / errore di autenticazione scaricando SM-P610
Il numero di serie manca, è sbagliato o non appartiene a un SM-P610. Deve avere
11 caratteri e iniziare con `R`. Controlla anche il CSC (`TABS6_CSC`): deve
essere uno per cui il firmware esiste (ITV, EUX, DBT, XEF, PHE, BTU...).

### `Latest available firmware could not be fetched`
Server Samsung non raggiungibile o CSC inesistente per quel modello. Riprova;
se persiste cambia CSC.

### `verify_target.sh` termina con FAIL
Apri `verify_target-report.md`. Ogni riga `FAIL` indica un valore di
`config.sh` diverso dal firmware reale:

| Riga | Correzione |
|---|---|
| Codename / SDK | Stai usando il firmware sbagliato (non SM-P610 Android 13) |
| Versione VNDK | Metti il valore stock in `TARGET_BOARD_API_LEVEL` (`platform/exynos9611/config.sh`). La base ha APEX VNDK per 30–34 |
| Dimensione super / gruppo | Copia i valori stock in `TARGET_SUPER_PARTITION_SIZE` e `TARGET_GROUP_BASIC_SIZE` |
| Gruppo super | Metti il nome stock in `TARGET_SUPER_GROUP_NAME` **e rinomina** la variabile `TARGET_GROUP_BASIC_SIZE` in `TARGET_<NOME_IN_MAIUSCOLO>_SIZE` |
| `floating_feature.xml in /system/etc` ASSENTE | Il firmware lo tiene altrove (di solito `/vendor/etc`): la base si aspetta `/system/etc`. Va adattato `unica/patches/__floating_feature` — apri una nota in roadmap |

Le righe `WARN` non fermano la build ma vanno corrette: sostituisci in
`overlay/target/gta4xlwifi/config.sh` il valore con quello della colonna
"Firmware stock" e togli il commento `[VERIFY]`.

### `Target camera portrait model directory is missing`
La base, per One UI 9, pretende `/system/cameradata/portrait_data` nel firmware
del dispositivo; il tablet (fotocamera singola) potrebbe non averla
(`verify_target-report.md` lo segnala come WARN). Soluzione: in
`un1ca/unica/patches/camera/customize.sh` rendere condizionali alla presenza
della cartella le righe che la copiano e la validano, e trasformare la modifica
in una patch applicata da `setup.sh`.

### `File not found: target/gta4xlwifi/overlay` (o `vintf`, `camera`, `dvfs`)
`gen_target_from_stock.sh` non è riuscito a generare quel file: guarda il suo
output (righe con `!`). Per l'overlay il motivo tipico è che apktool non decodifica
l'APK stock: decodificalo a mano (`apktool d -s`) e copia `res/` in
`overlay/target/gta4xlwifi/overlay/` (verrà mantenuto). Per andare avanti nel
frattempo: `./build.sh --debug`.

### `"dvfs_policy_..." does not exist in SDHMS app`
`TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME` non corrisponde a un file del
firmware. `gen_target_from_stock.sh` stampa l'elenco "stock SDHMS policies":
usa uno di quei nomi `dvfs_policy*`.

### La ROM non entra (errore su dimensione di `super` / gruppo) {#la-rom-non-entra}
Atteso: `super` è di soli 6,13 GiB.

```bash
cd un1ca && source buildenv.sh gta4xlwifi && ./tabs6-tools/size_report.sh
```

Aggiungi a `overlay/target/gta4xlwifi/debloat.sh` le cartelle più pesanti di cui
puoi fare a meno, partendo da: pacchetti lingua/voce offline, sfondi e video
dimostrativi, app duplicate Google/Samsung, modelli AI on-device (inutilizzabili
su questo hardware), AR Emoji/AR Zone, Bixby. **Non rimuovere**: `TeleService`,
`TelephonyUI`, `SecTelephonyProvider`, `SystemUI`, `SecSettings`, il launcher,
`SamsungDeviceHealthManagerService`, i provider. Dopo ogni rimozione che tocca
app di sistema, riprova l'avvio.

### Una patch della base non si applica / `skipped_patches.txt`
Le patch smali della base sono scritte per i suoi target. Su un tablet alcune
possono non applicarsi. `un1ca/out/skipped_patches.txt` elenca quelle saltate:
ognuna è una funzione che potrebbe non comportarsi come previsto (non per forza
un problema di avvio).

### Kernel: errore di compilazione
Prova in isolamento: `./tools/build_kernel.sh /tmp/k`. Con clang diverso dalla
18 possono comparire errori nuovi: usa Ubuntu 24.04 (o il workflow *Build
kernel only*). `git apply --check` fallito = la patch non corrisponde al commit:
vedi [05-kernel.md](05-kernel.md#aggiornare-il-kernel).

### `boot.img is N bytes, boot partition is 61865984 bytes`
Kernel troppo grande. Togli opzioni di debug da `config.fragment` o disattiva
`CONFIG_DEBUG_INFO` (non influisce sull'`Image`, ma verifica di non aver
attivato altro).

---

## Fase 1 — Il flash fallisce

| Sintomo | Causa | Rimedio |
|---|---|---|
| Odin: `only official released binaries are allowed to be flashed` | Sblocco OEM non confermato dopo il reset (stato KG/RMM "Prenormal") | Avvia stock, connetti al Wi-Fi, riapri Opzioni sviluppatore e verifica "Sblocco OEM". Può servire tenere il tablet acceso e online per alcuni giorni |
| Odin: `FAIL! (Auth)` o `SW REV CHECK FAIL` | Firmware stock con revisione bootloader più bassa di quella installata | Usa un firmware con revisione ≥ 7 |
| Recovery: `E: signature verification failed` | Recovery stock | Installa la recovery personalizzata (passo 2) |
| Recovery: `This package is for SM-P610...` / assert fallita | Modello diverso, o la recovery non espone `ro.boot.em.model` | Verifica il modello. Se è davvero un P610, annota quale proprietà espone la recovery (`adb shell getprop \| grep -i model`) |
| Recovery: errore scrivendo `super` / `map_partition` | Recovery senza supporto alle partizioni dinamiche | Usa la recovery LineageOS per gta4xlwifi |
| Zip installato ma avvia ancora il vecchio sistema | Flash interrotto | Reinstalla; controlla il log della recovery (`/tmp/recovery.log`) |

---

## Fase 2 — Non supera il logo Samsung

Il tablet resta sul logo "Samsung Galaxy Tab S6 Lite" con l'avviso del
bootloader sbloccato, oppure torna da solo in modalità Download/recovery.
Il kernel non parte o va in panic subito.

1. **Prova di controllo**: reinstalla lo zip usando il kernel stock **non**
   aiuta (non avvia Android 17), ma flashare la **`boot.img` stock** e poi di
   nuovo quella della ROM distingue un problema di scrittura da uno del kernel.
2. **Recupera il log dell'avvio precedente** dalla recovery:
   ```bash
   adb shell cat /proc/last_kmsg > last_kmsg.txt
   adb shell cat /sys/fs/pstore/console-ramoops-0 > ramoops.txt
   ```
   (uno dei due esiste a seconda del kernel). Cerca `Kernel panic`, `Unable to
   mount root`, `init:`.
3. Cause tipiche:

| Indizio | Causa | Rimedio |
|---|---|---|
| Nessun log, riavvio immediato | Il bootloader rifiuta la boot (formato/trailer) | Verifica con `unpack_bootimg` che header, offset e DTB siano identici alla stock. Prova `TARGET_BOOT_SEANDROID_MAGIC=false` in `config.sh` |
| Panic nei driver display/`decon` | DTB stock non compatibile con il kernel | Costruire `dtb`/`dtbo` dall'albero del kernel (cfg in `android_device_samsung_gta4xl-common/configs/kernel/`) invece di usare quelli stock |
| `Unable to mount` / `erofs` | EROFS non supportato come si pensava | `TARGET_OS_FILE_SYSTEM_TYPE="ext4"` in `platform/exynos9611/config.sh` (ma lo spazio non basterà: serve debloat pesante) |

---

## Fase 3 — Riavvio continuo prima dell'animazione

Il kernel parte, `init` no (o non monta le partizioni).

Log: `last_kmsg` come sopra; cerca righe `init:`.

| Messaggio | Causa | Rimedio |
|---|---|---|
| `Failed to mount ... /system` , `avb` , `vbmeta` | Verifica AVB ancora attiva | Controlla che lo zip abbia scritto `vbmeta` (log della recovery). In alternativa flasha a mano la `vbmeta_patched.img` (`un1ca/out/fw/SM-P610_*/avb/`) |
| `Could not find ... in logical partition table` | `super` incompleta | Reinstalla lo zip; verifica nomi/dimensioni del gruppo in `verify_target-report.md` |
| `Failed to load SELinux policy` / `sepolicy` | Policy vendor (Android 13) incompatibile con quella di sistema | Verifica che `unica/patches/selinux` sia stato applicato (log di `make_rom`). Diagnosi: `KERNEL_CMDLINE_EXTRA="androidboot.selinux=permissive"` |
| `Unable to decrypt` / `metadata` / `vold` | Dati cifrati residui | Formatta `/data` dalla recovery (Format, non Wipe) |
| `libc` / `linker`: `cannot locate symbol` in un HAL del vendor | VNDK mancante | Verifica che `com.android.vndk.v33.apex` sia in `system_ext/apex` (patch `vndk`) |

---

## Fase 4 — Bloccato o in loop sull'animazione di avvio

La fase più probabile al primo tentativo. Qui `adbd` di solito è già attivo:

```bash
adb logcat -b all > logcat.txt        # lascialo girare qualche minuto
adb shell getprop > props.txt
adb shell dmesg > dmesg.txt
```

Se `adb` risulta "unauthorized": la build di debug (`./build.sh --debug`)
abilita adb senza autorizzazione; in alternativa leggi i log dalla recovery
(sezione in fondo).

### `bpfloader-failed`
Riavvii a intervalli regolari; in recovery `adb shell getprop ro.boot.bootreason`
(o il `last_kmsg`) mostra `reboot,bpfloader-failed`.

1. In `dmesg`/`logcat` cerca `bpfloader`, `NetBpfLoad`, `netbpfload`.
2. `Android ... requires kernel 5.15+` (o simile): alza la versione dichiarata:
   `KERNEL_CMDLINE_EXTRA="uname_bpf_release=5.15.180" ./build.sh`
3. `Failed to load ... .o` / `critical`: un programma BPF usa qualcosa che il
   4.14 non ha. Opzioni, in ordine: (a) ramo `bpf-5.15` del kernel
   (`KERNEL_COMMIT`); (b) abbassare la versione dichiarata così quel programma
   non viene caricato; (c) la soluzione del port A52s: una copia di `netbpfload`
   con i controlli di versione scavalcati, eseguita da `/system`
   (`target/a52sxq/patches/tethering` nella base è il modello da adattare).

### `zygote` / `zygote-child` in crash (`Fatal signal 6`)
`system_server` non parte e il watchdog riavvia. Se nel log compare
`PR_CAPBSET_READ`/`cap`: il kernel non espone le capability attese. Controlla
`adb shell cat /proc/sys/kernel/cap_last_cap` → deve essere `40`. Se è meno, il
kernel flashato non è quello di questo repository.

### `system_server` in crash ripetuto
Cerca `FATAL EXCEPTION IN SYSTEM PROCESS` nel logcat. I casi tipici in un port:

| Eccezione / servizio | Causa | Dove intervenire |
|---|---|---|
| `NoSuchElementException` / `hwservicemanager` per un HAL `vendor.samsung.hardware.*` | Il framework cerca una versione di HAL che il vendor Android 13 non ha | `unica/patches/legacy` (modello) → nuova patch in `target/gta4xlwifi/patches` |
| Servizi biometrici (`face`, `fingerprint`) | Il tablet non ha impronte; la sorgente sì | Verificare `TARGET_FINGERPRINT_CONFIG_SENSOR`; controllare `skipped_patches.txt` |
| Telefonia (`TelephonyRegistry`, `phone`, `ril`) | Framework da telefono su dispositivo senza modem | Non rimuovere i pacchetti; verificare `ro.radio.noril`/`ro.telephony.*` rispetto alle prop stock (`props.txt` di stock) |
| `SemInputDeviceManager`, `spen`, `wacom` | Nodi sysfs S Pen | Confronta `dmesg` del kernel nuovo con quello stock per `wacom`/`epen` |
| `DisplayManager`, `mdnie`, `SemDisplaySolution` | Funzioni display dichiarate ma assenti | Voci `LCD_*`/`MDNIE` di `config.sh` (WARN del report) |

### Denial SELinux che bloccano l'avvio
`adb logcat | grep avc:` oppure `dmesg | grep avc`. Per capire se SELinux è
**la** causa: build con `KERNEL_CMDLINE_EXTRA="androidboot.selinux=permissive"`.
Se in permissive si avvia, raccogli gli `avc: denied` e aggiungi le regole
(modello: `unica/patches/selinux` e `target/a52sxq/patches/compat_sepolicy_mapping`).
Il permissive è solo diagnostico: non usarlo come soluzione.

### HAL del vendor uccisi durante i dump (`seccomp`)
Servizi codec/audio che muoiono quando un'app va in ANR: `crash_dump` di
Android 17 usa syscall non previste dai filtri seccomp del vendor Android 13.
Modello di correzione: `target/a52sxq/patches/media_seccomp_crashdump`.

### Sistema a 64 bit e HAL a 32 bit
Se il log mostra processi del vendor a 32 bit (audio, codec, DRM) che non
trovano `/system/lib/...` o il linker a 32 bit, la sorgente One UI 9 è priva
dell'userspace a 32 bit. Il report indica quanti HAL a 32 bit ha il vendor.
Modello di correzione: `target/a52sxq/patches/__desixtification` (innesta le
librerie a 32 bit). È la correzione più onerosa fra quelle elencate.

---

## Fase 5 — Si avvia ma qualcosa non funziona

Per ogni funzione: cosa guardare per primo.

| Funzione | Controlli |
|---|---|
| **Wi-Fi** | `dmesg \| grep -i -E "scsc\|wlan\|slsi"`; firmware in `/vendor/etc/wifi`; servizio `wpa_supplicant` in `logcat` |
| **Bluetooth** | `logcat \| grep -i bt_`; la base integra BluetoothLibraryPatcher |
| **Audio** (altoparlanti, jack, microfono) | `logcat \| grep -i -E "audio_hw\|AudioFlinger\|abox"`; i file `audio_policy_configuration*.xml` restano quelli stock del tablet |
| **Fotocamera** | `logcat \| grep -i -E "camera\|ExynosCamera"`; `camera/camera-feature.xml` generato da stock |
| **S Pen** | `adb shell getevent -l` muovendo la penna; voci `SPEN` del `floating_feature.xml` finale (`/system/etc/floating_feature.xml`); Air Command richiede le app Samsung S Pen presenti nella sorgente |
| **Rotazione / sensori** | `adb shell dumpsys sensorservice`; HAL sensori del vendor |
| **Luminosità automatica** | Voci `overlay/values/arrays.xml` (curva stock) e `LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS` |
| **Interfaccia da telefono** | `adb shell getprop ro.build.characteristics` deve dare `tablet`; densità `adb shell wm density` = 240 |
| **Taskbar / multitasking tablet** | Dipende da `characteristics` e dalle floating feature `FRAMEWORK_*` ereditate da stock |
| **DeX** | Sul 9611 stock è "DeX on tablet"; richiede le floating feature `COMMON_CONFIG_DEX_MODE` stock |
| **GPS** | `logcat \| grep -i gnss`; HAL `vendor.samsung.hardware.gnss@2.0` |
| **Ricarica / batteria** | `adb shell dumpsys battery`; `dmesg \| grep -i -E "battery\|charger"` |
| **Surriscaldamento / lentezza** | Policy termica generica (`ssrm_default`): valutare l'estrazione della policy stock; ridurre le app in background |
| **microSD** | `logcat \| grep -i vold`; driver sdFAT (gestito da `legacy`) |
| **Play Store "non certificato"** | Atteso con bootloader sbloccato; la base include moduli (PIF/keybox) che mitigano, non garantiscono |

---

## Come raccogliere i log

| Situazione | Comando |
|---|---|
| Sistema avviato o in animazione, adb attivo | `adb logcat -b all -d > logcat.txt` ; `adb shell dmesg > dmesg.txt` ; `adb bugreport` |
| Bootloop, adb non attivo | Riavvia in recovery subito dopo il fallimento, poi `adb shell cat /proc/last_kmsg` (o `/sys/fs/pstore/*`) |
| Motivo dell'ultimo riavvio | `adb shell getprop ro.boot.bootreason` ; `adb shell cat /proc/reset_reason` |
| Log persistenti su `/data` | In TWRP: `adb pull /data/system/dropbox` , `/data/tombstones` , `/data/anr` , `/data/log` |
| Log dell'installazione | In recovery: `adb pull /tmp/recovery.log` |
| Stato di riferimento | **Prima di installare la ROM**, da stock: `adb shell getprop > stock-props.txt`, `adb shell dmesg > stock-dmesg.txt`, `adb shell lshal > stock-lshal.txt`. Sono il termine di paragone per ogni problema hardware |

Quando chiedi aiuto allega: build/commit di questo repository,
`verify_target-report.md`, `skipped_patches.txt`, e i log della fase in cui si ferma.
