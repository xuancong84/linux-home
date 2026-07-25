#!/usr/bin/env bash
set -eo pipefail

PGSRIP=/opt/anaconda3/bin/python3

# ── Usage ──────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <input.mkv> [output.mp4]" >&2
    exit 1
fi

INPUT=$1
OUTPUT=${2:-${INPUT%.mkv}.mp4}
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# ── Embed OCR helper into temp dir ──────────────────────────────────────────
PGSRIP_SCRIPT="$TMPDIR/pgsrip_batch.py"
cat > "$PGSRIP_SCRIPT" <<'PYEOF'
import sys, os, site, warnings
warnings.filterwarnings('ignore')

_user_site = site.getusersitepackages()

BATCH_SIZE = 100
MAX_WIDTH  = 2000

TESS_TO_EASYOCR = {
    'chi_sim': ['ch_sim', 'en'],
    'chi_tra': ['ch_tra', 'en'],
    'eng':     ['en'],
    'kor':     ['ko'],
    'jpn':     ['ja'],
    'fra':     ['fr'],
    'deu':     ['de'],
    'spa':     ['es'],
    'por':     ['pt'],
    'rus':     ['ru'],
    'ara':     ['ar'],
}

def _gpu_available():
    try:
        import importlib.util
        if importlib.util.find_spec('torch') is None:
            return False
        import torch
        return torch.cuda.is_available()
    except Exception:
        return False

def _ensure_easyocr():
    import importlib.util
    if importlib.util.find_spec('easyocr') is not None:
        return True
    import subprocess
    print("  easyocr not found — installing to ~/.local (pip install --user easyocr) ...", flush=True)
    r = subprocess.run([sys.executable, '-m', 'pip', 'install', '--user', 'easyocr'],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  pip install failed: {r.stderr.strip()}", flush=True)
        return False
    if _user_site not in sys.path:
        sys.path.insert(0, _user_site)
    return importlib.util.find_spec('easyocr') is not None

def try_easyocr(lang_codes, gpu=True, sentinel=None):
    if sentinel and os.path.exists(sentinel):
        return None
    try:
        import easyocr
        return easyocr.Reader(lang_codes, gpu=gpu, verbose=False)
    except Exception as e:
        print(f"  EasyOCR unavailable ({e}), falling back to tesseract", flush=True)
        if sentinel:
            try:
                open(sentinel, 'w').close()
            except OSError:
                pass
        return None

def rip_with_easyocr(pgs, options, reader):
    import numpy as np
    from pysrt import SubRipFile, SubRipItem, SubRipTime
    srt_path = str(pgs.media_path.translate(extension='srt'))
    subs = SubRipFile(path=srt_path)
    all_items = list(pgs.items)
    n = len(all_items)
    if n == 0:
        subs.save(encoding=options.encoding)
        print("  0 subtitle entries, nothing to do", flush=True)
        return
    print(f"  {n} subtitle entries via EasyOCR (GPU)", flush=True)
    for i, item in enumerate(all_items):
        img = item.image.data
        if img is None or img.size == 0:
            continue
        img3 = np.stack([img, img, img], axis=-1)
        try:
            results = reader.readtext(img3, detail=0, paragraph=False)
            text = '\n'.join(r.strip() for r in results if r.strip())
        except Exception:
            text = ''
        if text:
            start = SubRipTime(milliseconds=item.start)
            end   = SubRipTime(milliseconds=item.end)
            subs.append(SubRipItem(i, start=start, end=end, text=text))
        if (i + 1) % 200 == 0:
            print(f"  EasyOCR: {i+1}/{n}", flush=True)
    subs.clean_indexes()
    subs.save(encoding=options.encoding)
    print(f"  -> {len(subs)} entries written to {srt_path}", flush=True)

def rip_in_batches(pgs, options, batch_size=BATCH_SIZE, max_width=MAX_WIDTH):
    from pgsrip.ripper import PgsToSrtRipper
    from pysrt import SubRipFile
    ripper = PgsToSrtRipper(pgs, options)
    rules  = options.config.select_rules(tags=options.tags, languages={pgs.language})
    post_process = lambda t: rules.apply(t, '')[0]
    srt_path = str(pgs.media_path.translate(extension='srt'))
    subs     = SubRipFile(path=srt_path)
    all_items = list(pgs.items)
    n = len(all_items)
    if n == 0:
        subs.save(encoding=options.encoding)
        print("  0 subtitle entries, nothing to do", flush=True)
        return
    n_batches = (n + batch_size - 1) // batch_size
    print(f"  {n} subtitle entries -> {n_batches} batch(es) via tesseract", flush=True)
    for bi in range(n_batches):
        batch = all_items[bi * batch_size:(bi + 1) * batch_size]
        batch_max_h = max(item.height for item in batch) // 2
        ripper.gap  = (batch_max_h // 2 + 30, batch_max_h // 2 + 100)
        try:
            remaining = ripper.process(subs, batch, post_process,
                                       ripper.confidence, max_width,
                                       ripper.oem, ripper.psm)
        except Exception as e:
            print(f"  Batch {bi+1} failed ({e}), retrying individually...", flush=True)
            remaining = []
            for item in batch:
                try:
                    ripper.gap = (item.height // 4 + 30, item.height // 4 + 100)
                    ripper.process(subs, [item], post_process, 0,
                                   max(item.width + 200, 500), ripper.oem, ripper.psm)
                except Exception:
                    pass
        if remaining:
            narrow    = min(sum(item.width + ripper.gap[1] for item in remaining), max_width)
            retry_max = max(item.height for item in remaining) // 2
            ripper.gap = (retry_max // 2 + 30, retry_max // 2 + 100)
            try:
                ripper.process(subs, remaining, post_process, 0, narrow, ripper.oem, ripper.psm)
            except Exception:
                pass
        n_done = min((bi + 1) * batch_size, n)
        print(f"  Batch {bi+1}/{n_batches}: {n_done}/{n} processed", flush=True)
    subs.clean_indexes()
    subs.save(encoding=options.encoding)
    print(f"  -> {len(subs)} entries written to {srt_path}", flush=True)

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <file.IETF.sup> <ietf_lang> [tessdata_prefix] [tess_name]",
              file=sys.stderr)
        sys.exit(1)
    sup_path        = sys.argv[1]
    ietf_lang       = sys.argv[2]
    tessdata_prefix = sys.argv[3] if len(sys.argv) > 3 else None
    tess_name       = sys.argv[4] if len(sys.argv) > 4 else None
    if tessdata_prefix:
        os.environ['TESSDATA_PREFIX'] = tessdata_prefix
    import cleanit.subtitle
    from babelfish import Language
    from pgsrip.sup import Sup
    from pgsrip.options import Options
    lang    = Language.fromcleanit(ietf_lang)
    options = Options(languages={lang}, overwrite=True)
    sup      = Sup(sup_path)
    pgs_list = list(sup.get_pgs_medias(options))
    if not pgs_list:
        print(f"ERROR: no matching PGS in {sup_path} for lang={ietf_lang}", file=sys.stderr)
        sys.exit(2)
    sentinel = os.path.join(os.path.dirname(sup_path), '.easyocr_failed')
    with pgs_list[0] as pgs:
        easyocr_langs = TESS_TO_EASYOCR.get(tess_name) if tess_name else None
        reader = None
        if easyocr_langs and _gpu_available():
            if _ensure_easyocr():
                print(f"  Trying EasyOCR (langs={easyocr_langs}, gpu=True) ...", flush=True)
                reader = try_easyocr(easyocr_langs, gpu=True, sentinel=sentinel)
        elif easyocr_langs:
            print("  GPU CUDA not available — using tesseract fallback", flush=True)
        if reader is not None:
            rip_with_easyocr(pgs, options, reader)
        else:
            rip_in_batches(pgs, options)

if __name__ == '__main__':
    main()
PYEOF

echo "Input:  $INPUT"
echo "Output: $OUTPUT"
echo ""

# ── Detect installed tessdata languages ────────────────────────────────────
# Build list of tessdata dirs to search
declare -a TESSDATA_DIRS=(
    /usr/share/tesseract-ocr/5/tessdata
    /usr/share/tesseract-ocr/tessdata
    /usr/share/tessdata
    "$HOME/.local/share/tessdata"
    /opt/anaconda3/share/tessdata
)

declare -A INSTALLED_TESS=()   # name → full path
for dir in "${TESSDATA_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r f; do
        name=$(basename "$f" .traineddata)
        [[ "$name" == "osd" || "$name" == "equ" ]] && continue
        INSTALLED_TESS[$name]=$f
    done < <(find "$dir" -maxdepth 1 -name "*.traineddata" 2>/dev/null)
done

echo "Installed OCR tessdata: ${!INSTALLED_TESS[*]}"
echo ""

# ── Language mapping ────────────────────────────────────────────────────────

# MKV ISO 639-2 lang + stream title → ordered tessdata candidates (space-sep)
tess_candidates() {
    local lang=$1 title=$2
    case $lang in
        eng)      echo "eng" ;;
        chi|zho)
            if echo "$title" | grep -qP '简|简体|Simplified'; then
                echo "chi_sim chi_tra"
            elif echo "$title" | grep -qP '繁|繁体|Traditional'; then
                echo "chi_tra chi_sim"
            else
                echo "chi_sim chi_tra"
            fi
            ;;
        kor)      echo "kor" ;;
        jpn)      echo "jpn" ;;
        fra|fre)  echo "fra" ;;
        deu|ger)  echo "deu" ;;
        spa)      echo "spa" ;;
        por)      echo "por" ;;
        rus)      echo "rus" ;;
        ara)      echo "ara" ;;
        *)        echo "" ;;
    esac
}

# tessdata name → pgsrip IETF code used in .sup filename and -l flag
# Must match what Language.fromcleanit() accepts, and str(Language) returns.
# English: 'en'; Simplified Chinese: 'zh'; Traditional Chinese: 'zh-TW'; etc.
tess_to_ietf() {
    case $1 in
        eng)     echo "en" ;;
        chi_sim) echo "zh" ;;
        chi_tra) echo "zh-TW" ;;
        kor)     echo "ko" ;;
        jpn)     echo "ja" ;;
        fra)     echo "fr" ;;
        deu)     echo "de" ;;
        spa)     echo "es" ;;
        por)     echo "pt" ;;
        rus)     echo "ru" ;;
        ara)     echo "ar" ;;
        *)       echo "" ;;
    esac
}

# ── Prepare custom tessdata dirs ────────────────────────────────────────────
# pgsrip passes language.alpha3 to tesseract as the lang parameter.
# For Chinese (zh/zh-TW), babelfish alpha3 = 'zho', which doesn't match
# the tessdata filenames 'chi_sim' / 'chi_tra'.  We create a custom tessdata
# directory per distinct chosen tessdata where we symlink all installed files
# and add a 'zho.traineddata' → chosen file override.

declare -A TESS_DIRS=()   # chosen tessdata → custom dir path

setup_tess_dir() {
    local chosen=$1
    [[ "${TESS_DIRS[$chosen]+_}" ]] && { echo "${TESS_DIRS[$chosen]}"; return; }

    local tdir="$TMPDIR/tessdata_$chosen"
    mkdir -p "$tdir"

    # Symlink all installed tessdata into the custom dir
    for name in "${!INSTALLED_TESS[@]}"; do
        ln -sf "${INSTALLED_TESS[$name]}" "$tdir/$name.traineddata"
    done

    # For Chinese: tesseract receives lang='zho' (babelfish alpha3),
    # so create a 'zho.traineddata' symlink → the chosen file.
    case $chosen in
        chi_sim|chi_tra)
            ln -sf "${INSTALLED_TESS[$chosen]}" "$tdir/zho.traineddata"
            ;;
    esac

    TESS_DIRS[$chosen]=$tdir
    echo "$tdir"
}

IMAGE_SUB_CODECS=" hdmv_pgs_subtitle dvd_subtitle pgssub dvbsub "
is_image_sub() { [[ "$IMAGE_SUB_CODECS" == *" $1 "* ]]; }

# ── Parse all streams ───────────────────────────────────────────────────────
STREAM_INFO=$(python3 - "$INPUT" <<'EOF'
import json, sys, subprocess
r = subprocess.run(
    ['ffprobe', '-v', 'quiet', '-print_format', 'json', '-show_streams', sys.argv[1]],
    capture_output=True, text=True, check=True
)
for s in json.loads(r.stdout)['streams']:
    t = s.get('tags', {})
    title = t.get('title', '').replace('\n', ' ').replace('|', '/')
    print(f"{s['index']}|{s['codec_type']}|{s['codec_name']}|{t.get('language','und')}|{title}")
EOF
)

# ── Process each stream ─────────────────────────────────────────────────────
declare -a VIDEO_MAPS=()
declare -a AUDIO_MAPS=()
declare -a TEXT_SUB_MAPS=()
declare -a SRT_FILES=()
declare -a SRT_LANGS=()
declare -a SRT_TITLES=()

while IFS='|' read -r idx stype codec lang title; do
    case $stype in
        video)
            VIDEO_MAPS+=("0:$idx")
            ;;
        audio)
            AUDIO_MAPS+=("0:$idx")
            ;;
        subtitle)
            if is_image_sub "$codec"; then
                # Find the first installed tessdata candidate
                candidates=$(tess_candidates "$lang" "$title")
                chosen=""
                for cand in $candidates; do
                    if [[ "${INSTALLED_TESS[$cand]+_}" ]]; then
                        chosen=$cand
                        break
                    fi
                done

                if [[ -n "$chosen" ]]; then
                    ietf=$(tess_to_ietf "$chosen")
                    # pgsrip derives language from filename: base.IETF.sup
                    sup="$TMPDIR/s${idx}.${ietf}.sup"
                    # pgsrip creates srt at same base.IETF.srt
                    srt="$TMPDIR/s${idx}.${ietf}.srt"
                    tdir=$(setup_tess_dir "$chosen")

                    echo "[Stream $idx] Image subtitle ($codec), lang=$lang, title='$title'"
                    echo "  → OCR with tessdata=$chosen (pgsrip -l $ietf, TESSDATA_PREFIX=$tdir)"

                    printf "  → Extracting .sup ... "
                    ffmpeg -y -loglevel error -i "$INPUT" -map "0:$idx" -c copy "$sup" < /dev/null
                    echo "done ($(du -sh "$sup" | cut -f1))"

                    printf "  → Running pgsrip (batch OCR) ... \n"
                    if "$PGSRIP" "$PGSRIP_SCRIPT" "$sup" "$ietf" "$tdir" "$chosen" < /dev/null; then
                        if [[ -f "$srt" ]]; then
                            SRT_FILES+=("$srt")
                            SRT_LANGS+=("$lang")
                            SRT_TITLES+=("$title")
                            echo "done → $(wc -l < "$srt") lines"
                        else
                            echo "WARNING: pgsrip exited OK but $srt not found"
                        fi
                    else
                        echo "WARNING: pgsrip failed (exit $?)"
                    fi
                else
                    needed=$(tess_candidates "$lang" "$title")
                    echo "[Stream $idx] Image subtitle ($codec), lang=$lang, title='$title'"
                    if [[ -n "$needed" ]]; then
                        echo "  → DISCARDED: no OCR support (missing tessdata: $needed)"
                    else
                        echo "  → DISCARDED: language '$lang' not in OCR mapping table"
                    fi
                fi
            else
                echo "[Stream $idx] Text subtitle ($codec), lang=$lang, title='$title' → COPIED"
                TEXT_SUB_MAPS+=("0:$idx")
            fi
            echo ""
            ;;
    esac
done <<< "$STREAM_INFO"

# ── Assemble final .mp4 ─────────────────────────────────────────────────────
declare -a FFMPEG_ARGS=(ffmpeg -y -loglevel warning -i "$INPUT")

# Additional SRT inputs (input indices 1, 2, ...)
for f in "${SRT_FILES[@]}"; do FFMPEG_ARGS+=(-i "$f"); done

# Stream mappings: video → audio → text subs → OCR'd SRTs
for m in "${VIDEO_MAPS[@]}";    do FFMPEG_ARGS+=(-map "$m"); done
for m in "${AUDIO_MAPS[@]}";    do FFMPEG_ARGS+=(-map "$m"); done
for m in "${TEXT_SUB_MAPS[@]}"; do FFMPEG_ARGS+=(-map "$m"); done
for j in "${!SRT_FILES[@]}";    do FFMPEG_ARGS+=(-map "$((j+1)):0"); done

# Codecs; -map_chapters -1 suppresses the chapter data track (bin_data) in MP4
FFMPEG_ARGS+=(-c:v copy -c:a copy -map_chapters -1)
total_subs=$(( ${#TEXT_SUB_MAPS[@]} + ${#SRT_FILES[@]} ))
[[ $total_subs -gt 0 ]] && FFMPEG_ARGS+=(-c:s mov_text)

# Language + title metadata for each OCR'd subtitle output stream
n_text=${#TEXT_SUB_MAPS[@]}
for j in "${!SRT_FILES[@]}"; do
    si=$((n_text + j))
    FFMPEG_ARGS+=("-metadata:s:s:$si" "language=${SRT_LANGS[$j]}")
    [[ -n "${SRT_TITLES[$j]}" ]] && FFMPEG_ARGS+=("-metadata:s:s:$si" "title=${SRT_TITLES[$j]}")
done

FFMPEG_ARGS+=("$OUTPUT")

echo "Assembling $OUTPUT ..."
"${FFMPEG_ARGS[@]}"
echo ""
echo "Done: $OUTPUT"
