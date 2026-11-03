"""Turns the raw simulator recording into an App Store app preview.

    python3 tool/make_preview.py RAW.mp4 RECORD_START_EPOCH_MS DRIVE.log OUT.mp4

Cuts the recording at the scenes printed by integration_test/preview_test.dart
("PREVIEW <epoch ms> <scene>"), puts the app on an 886x1920 canvas (the size
App Store accepts for 6.9" / 6.7" iPhones) with a caption per scene, adds a
silent stereo track (previews need audio) and encodes H.264 30 fps, at most
30 seconds.
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

CAPTIONS = {
    'intro': '道具なし、準備なし。\n今すぐ遊べる',
    'deal': '役とお題は\nスマホを回して配る',
    'filter': '人数と時間で\nぴったりの遊びを',
    'topics': 'お題もタイマーも\nおまかせ',
    'end': '42種類の遊びと\nAIが考える遊び',
}
W, H = 886, 1920
BAND = 330          # caption area at the top
APP_H = H - BAND - 40
FONT = Path(__file__).resolve().parent.parent / 'assets/fonts/MPLUSRounded1c-ExtraBold.ttf'
BG = '0xFDFBF7'     # AppColors.background
INK = '0x2C3E50'    # AppColors.tintColor
MAX_SECONDS = 29.5
LINE_H = 96


def scenes(log_text, record_start_ms):
    found = [(int(ms), name) for ms, name in re.findall(r'PREVIEW (\d{13}) (\w+)', log_text)]
    if not found or found[-1][1] != 'done':
        sys.exit('no complete PREVIEW scene list in the drive log')
    first = found[0][0]
    return [((ms - first) / 1000, name) for ms, name in found], (first - record_start_ms) / 1000


def filter_graph(timeline, workdir):
    duration = min(timeline[-1][0], MAX_SECONDS)
    parts = [
        f'[0:v]fps=30,scale=-2:{APP_H}:flags=lanczos,setsar=1[app]',
        f'color=c={BG}:s={W}x{H}:r=30:d={duration:.3f}[bg]',
        f'[bg][app]overlay=x=(W-w)/2:y={BAND}:shortest=1[v0]',
    ]
    label = 'v0'
    for i, (start, name) in enumerate(timeline[:-1]):
        end = min(timeline[i + 1][0], duration)
        text = CAPTIONS.get(name)
        if not text:
            continue
        # One drawtext per line, so every line is centred.
        lines = text.split('\n')
        top = (BAND - len(lines) * LINE_H) // 2
        for j, line in enumerate(lines):
            txt = Path(workdir) / f'{name}-{j}.txt'
            txt.write_text(line, encoding='utf-8')
            nxt = f'v{i + 1}_{j}'
            parts.append(
                f"[{label}]drawtext=fontfile='{FONT}':textfile='{txt}':fontsize=66:fontcolor={INK}"
                f":x=(w-text_w)/2:y={top + j * LINE_H}"
                f":enable='between(t,{start:.3f},{end:.3f})'[{nxt}]"
            )
            label = nxt
    return ';'.join(parts), label, duration


def main():
    raw, record_start_ms, log_path, out = sys.argv[1:5]
    timeline, offset = scenes(Path(log_path).read_text(errors='replace'), int(record_start_ms))
    if offset < 0:
        sys.exit(f'scene starts {offset:.1f}s before the recording')
    with tempfile.TemporaryDirectory() as workdir:
        graph, label, duration = filter_graph(timeline, workdir)
        Path(out).parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([
            'ffmpeg', '-y', '-loglevel', 'error',
            '-ss', f'{offset:.3f}', '-t', f'{duration:.3f}', '-i', raw,
            '-f', 'lavfi', '-t', f'{duration:.3f}', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
            '-filter_complex', graph, '-map', f'[{label}]', '-map', '1:a',
            '-c:v', 'libx264', '-profile:v', 'high', '-level', '4.0', '-pix_fmt', 'yuv420p',
            '-b:v', '10M', '-maxrate', '12M', '-bufsize', '20M', '-r', '30',
            '-c:a', 'aac', '-b:a', '256k', '-movflags', '+faststart',
            '-t', f'{duration:.3f}', out,
        ], check=True)
    print(f'{out}: {duration:.1f}s, scenes: ' + ', '.join(f'{n}@{s:.1f}' for s, n in timeline))


if __name__ == '__main__':
    main()
