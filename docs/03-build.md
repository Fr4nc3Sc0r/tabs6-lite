# 3. Build

Due modi: **GitHub Actions** (consigliato: non serve un PC potente) oppure in
locale su Linux.

## Cosa serve in ogni caso: il numero di serie del tablet

Samsung distribuisce i firmware solo a chi presenta un identificativo valido
per quel modello. Un tablet Wi-Fi non ha IMEI: serve il **numero di serie**
(11 caratteri, inizia con `R`, es. `R52N40ABCDE`).

Dove trovarlo: *Impostazioni → Informazioni sul tablet → Numero di serie*,
oppure stampato in piccolo sul retro.

> Non scrivere mai il numero di serie in un file del repository o in una issue.
> Passa solo dalla variabile `TABS6_SERIAL` (o dal secret omonimo). Il file
> `un1ca/out/config.sh` lo contiene: non condividerlo.

## A. GitHub Actions

1. Nel repository: **Settings → Secrets and variables → Actions → New repository
   secret**. Nome `TABS6_SERIAL`, valore il numero di serie.
2. **Actions → Build ROM (gta4xlwifi) → Run workflow**.
3. Prima esecuzione: lascia `mode = probe`. Scarica ed estrae i firmware,
   genera i file dal firmware stock e produce `verify_target-report.md`
   (artifact `reports-N`). Non costruisce la ROM. **Serve a correggere la
   configurazione prima di investire ore in una build.**
4. Quando il report non ha `FAIL` (e idealmente nessun `WARN`): rilancia con
   `mode = rom`. Lo zip flashabile è nell'artifact `rom-N`.

Note:

- Il workflow parte solo a mano (`workflow_dispatch`), dal ramo selezionato
  nel menu. Perché compaia nella scheda Actions il file deve trovarsi nel ramo
  predefinito del repository.
- GitHub maschera automaticamente il secret nei log.
- I runner gratuiti hanno disco e tempo limitati (6 ore per job). Il workflow
  libera spazio prima di iniziare; se non bastasse serve la build locale. La
  compilazione del kernel (circa mezz'ora su 4 core) si può anticipare con il workflow *Build kernel only* e
  `KERNEL_PREBUILT_IMAGE`.
- `debug = true` trasforma in avvisi gli errori per file dispositivo mancanti:
  utile solo per vedere quanto lontano arriva la build, non per flashare.

## B. In locale

Requisiti: Linux x86_64 (Ubuntu 24.04 è quello provato dalla base), ~80 GB di
disco libero, 16 GB di RAM, connessione veloce (~15 GB di firmware).

```bash
sudo apt install 7zip attr bc binutils bison brotli build-essential ccache clang cmake cpio ffmpeg \
  file flex fuse2fs fuse3 \
  git golang libbrotli-dev liblz4-dev libudev-dev ninja-build pkg-config zip zstd \
  libbz2-dev libelf-dev libgtest-dev libprotobuf-dev libunwind-dev libpcre2-dev \
  libssl-dev libxml2-utils libzstd-dev lld llvm lz4 openjdk-17-jdk \
  protobuf-compiler python3-venv rsync webp
sudo modprobe erofs f2fs

git clone <questo repository> && cd tabs6-lite
export TABS6_SERIAL=R...........
./build.sh --probe-only     # verifica
./build.sh                  # ROM completa
```

Risultato: `un1ca/out/UN1CA_*_gta4xlwifi*.zip`.
Log: `un1ca/out/target/gta4xlwifi/*.log`. Report: `un1ca/out/verify_target-report.md`.

### Variabili d'ambiente

| Variabile | Default | Effetto |
|---|---|---|
| `TABS6_SERIAL` | — (obbligatoria) | Numero di serie per scaricare il firmware SM-P610 |
| `TABS6_CSC` | `ITV` | CSC del firmware stock (Italia). Vendor e kernel sono identici fra CSC europei |
| `TABS6_KEEP_ENCRYPTION` | `false` | `true` = non toccare la cifratura di `/data` |
| `KERNEL_COMMIT` / `KERNEL_REPO` | fissati | Altro commit/albero del kernel |
| `KERNEL_PREBUILT_IMAGE` | — | Usa un `Image` già compilato (salta la compilazione) |
| `KERNEL_CMDLINE_EXTRA` | — | Testo aggiunto alla cmdline del kernel (vedi [05-kernel.md](05-kernel.md)) |
| `KERNEL_JOBS` | `nproc` | Parallelismo della compilazione |
| `BASE_COMMIT` / `BASE_REPO` | fissati | Altra versione della base |

### Lavorare dentro la base

```bash
cd un1ca
source buildenv.sh gta4xlwifi      # serve TABS6_SERIAL nell'ambiente
run_cmd make_rom --build-rom-zip   # ricostruisce solo ciò che è cambiato
run_cmd make_rom -f --build-rom-zip  # forza la ricostruzione
./tabs6-tools/size_report.sh
```

Attenzione: `setup.sh` ricopia `overlay/` dentro `un1ca/` a ogni esecuzione.
**Modifica sempre i file in `overlay/` e `tools/`**, non le copie in `un1ca/`,
altrimenti le modifiche vengono sovrascritte e non finiscono nel repository.

## Solo il kernel

```bash
./tools/build_kernel.sh /tmp/kernel-out
# -> /tmp/kernel-out/Image, config, version.txt
KERNEL_PREBUILT_IMAGE=/tmp/kernel-out/Image ./build.sh
```

Non richiede firmware Samsung né numero di serie. Provato su Ubuntu 24.04 con
clang 18.1.3: produce `Linux version 4.14.357` (~38 MB).

## Cosa aspettarsi alla prima build

Con ogni probabilità **non andrà a buon fine al primo colpo**. Gli arresti più
probabili, in ordine, e cosa fare, sono in
[06-troubleshooting.md](06-troubleshooting.md#fase-0--la-build-non-termina).

## Verifica senza tablet

Dopo `./build.sh`, prima di flashare:

```bash
sudo apt install qemu-user-static qemu-system-arm
tools/emu_check.sh        # collegamento di programmi e librerie, policy SELinux
tools/vm_boot.sh          # avvio nel tablet virtuale (QEMU), 10 minuti
```

Servono i permessi `sudo` (montaggi e chroot). Cosa provano e cosa no è spiegato
in [07-stato-e-roadmap.md](07-stato-e-roadmap.md).
