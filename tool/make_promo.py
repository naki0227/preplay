"""Turns the raw simulator recording into a vertical promotion video for
social media (TikTok, Instagram Reels, YouTube Shorts, X).

    python3 tool/make_promo.py RAW.mp4 DRIVE.log OUT.mp4

Reads the scene and tap times printed by integration_test/promo_test.dart
("PREVIEW <epoch ms> <name>") and lines them up with the recording through
the magenta "sync" flash the test shows before the first scene. Puts the app with rounded corners on a warm
gradient with a big caption per scene, ends with a card (icon, name,
"App Storeで無料"), and adds music and tap sounds from tool/make_bgm.py.
1080x1920, H.264 30 fps, AAC stereo.
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_bgm  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / 'assets/fonts/MPLUSRounded1c-ExtraBold.ttf'
FONT_BOLD = ROOT / 'assets/fonts/MPLUSRounded1c-Bold.ttf'
ICON = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png'

W, H = 1080, 1920
BAND = 370                 # caption area at the top
APP_H = 1490               # app footage height
RADIUS = 56
TOP, BOTTOM = (255, 244, 226), (255, 196, 140)   # gradient: cream -> soft orange
INK = '0x2C3E50'
END_SECONDS = 3.2
MAX_SECONDS = 34

CAPTIONS = {
    'intro': '「何する？」で\n迷う時間、ゼロに。',
    'deal': 'ワードウルフの役も\nスマホを回して配るだけ',
    'filter': '人数と時間で\nすぐ見つかる',
    'topics': 'お題もタイマーも\nおまかせ',
}


def parse(log_text):
    """Returns scenes and taps in seconds from the first scene, and the
    first scene's time after the sync flash."""
    events = [(int(ms), name) for ms, name in re.findall(r'PREVIEW (\d{13}) (\w+)', log_text)]
    sync = [ms for ms, name in events if name == 'sync']
    scenes = [e for e in events if e[1] not in ('tap', 'sync')]
    if not sync or not scenes or scenes[-1][1] != 'done' or 'end' not in [n for _, n in scenes]:
        sys.exit('no complete PREVIEW scene list in the drive log')
    first = scenes[0][0]
    rel = lambda ms: (ms - first) / 1000  # noqa: E731
    timeline = [(rel(ms), name) for ms, name in scenes]
    taps = [rel(ms) for ms, name in events if name == 'tap' and ms >= first]
    return timeline, taps, (first - sync[0]) / 1000


def find_flash(raw):
    """Time of the first magenta frame in the recording (U and V both high)."""
    with tempfile.NamedTemporaryFile('r', suffix='.txt') as stats:
        subprocess.run([
            'ffmpeg', '-loglevel', 'error', '-i', raw,
            '-vf', f'scale=64:-2,crop=32:32,signalstats,metadata=print:file={stats.name}',
            '-f', 'null', '-',
        ], check=True)
        t = None
        for line in stats.read().splitlines():
            if line.startswith('frame:'):
                t = float(re.search(r'pts_time:([\d.]+)', line).group(1))
                u = v = 0.0
            elif 'signalstats.UAVG=' in line:
                u = float(line.split('=')[1])
            elif 'signalstats.VAVG=' in line:
                v = float(line.split('=')[1])
                if u > 180 and v > 190:
                    return t
    sys.exit('sync flash not found in the recording')


def gradient():
    img = Image.new('RGB', (W, H))
    px = img.load()
    for y in range(H):
        k = y / (H - 1)
        c = tuple(round(a + (b - a) * k) for a, b in zip(TOP, BOTTOM))
        for x in range(W):
            px[x, y] = c
    return img


def rounded_mask(w, h, r):
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), r, fill=255)
    return m


def shadow(w, h, r):
    pad = 60
    img = Image.new('RGBA', (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle((pad, pad + 16, pad + w, pad + h + 16), r, fill=(90, 50, 20, 90))
    return img.filter(ImageFilter.GaussianBlur(28)), pad


def end_card():
    img = gradient().convert('RGBA')
    d = ImageDraw.Draw(img)
    icon = Image.open(ICON).convert('RGBA').resize((380, 380), Image.LANCZOS)
    sh, pad = shadow(380, 380, 84)
    img.alpha_composite(sh, ((W - sh.width) // 2, 430 - pad))
    img.paste(icon, ((W - 380) // 2, 430), rounded_mask(380, 380, 84))

    def center(text, y, size, font=FONT, fill=(44, 62, 80)):
        f = ImageFont.truetype(str(font), size)
        w = d.textlength(text, font=f)
        d.text(((W - w) / 2, y), text, font=f, fill=fill)

    center('Preplay', 880, 132)
    center('道具なし・準備なし', 1080, 64, FONT_BOLD)
    center('その場で遊べるゲーム集', 1170, 64, FONT_BOLD)
    pill_w, pill_h, y = 640, 132, 1390
    d.rounded_rectangle(((W - pill_w) // 2, y, (W + pill_w) // 2, y + pill_h), pill_h // 2, fill=(44, 62, 80))
    f = ImageFont.truetype(str(FONT), 60)
    text = 'App Storeで無料'
    tw = d.textlength(text, font=f)
    d.text(((W - tw) / 2, y + 30), text, font=f, fill=(255, 255, 255))
    return img.convert('RGB')


def build(raw, log_path, out):
    timeline, taps, after_sync = parse(Path(log_path).read_text(errors='replace'))
    offset = find_flash(raw) + after_sync
    footage = next(t for t, n in timeline if n == 'end')
    total = min(footage + END_SECONDS, MAX_SECONDS)
    footage = total - END_SECONDS
    app_w = round(APP_H * 1320 / 2868 / 2) * 2

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        gradient().save(tmp / 'bg.png')
        rounded_mask(app_w, APP_H, RADIUS).save(tmp / 'mask.png')
        sh, pad = shadow(app_w, APP_H, RADIUS)
        sh.save(tmp / 'shadow.png')
        end_card().save(tmp / 'end.png')
        make_bgm.write(str(tmp / 'audio.wav'), make_bgm.render(total, [t for t in taps if t < footage]))

        app_x, app_y = (W - app_w) // 2, BAND
        g = [
            f'[0:v]fps=30,scale={app_w}:{APP_H}:flags=lanczos,setsar=1,format=rgba[raw]',
            '[2:v]format=gray[m]',
            '[raw][m]alphamerge[app]',
            f'[1:v][3:v]overlay={app_x - pad}:{app_y - pad}[bg1]',
            f'[bg1][app]overlay={app_x}:{app_y}:shortest=1[v0]',
        ]
        label = 'v0'
        line_h = 112
        for i, (start, name) in enumerate(timeline):
            text = CAPTIONS.get(name)
            if not text or start >= footage:
                continue
            end = min(timeline[i + 1][0], footage)
            lines = text.split('\n')
            top = (BAND - len(lines) * line_h) // 2 + 6
            for j, line in enumerate(lines):
                f = tmp / f'{name}-{j}.txt'
                f.write_text(line, encoding='utf-8')
                nxt = f'{label}c{j}'
                fade = f"if(lt(t,{start + 0.25:.3f}),(t-{start:.3f})/0.25,1)"
                g.append(
                    f"[{label}]drawtext=fontfile='{FONT}':textfile='{f}':fontsize=86:fontcolor={INK}"
                    f":borderw=10:bordercolor=white:x=(w-text_w)/2:y={top + j * line_h}"
                    f":alpha='{fade}':enable='between(t,{start:.3f},{end:.3f})'[{nxt}]"
                )
                label = nxt
        g.append(f"[4:v]format=rgba,fade=t=in:st=0:d=0.35:alpha=1,setpts=PTS+{footage:.3f}/TB[endc]")
        g.append(f"[{label}][endc]overlay=0:0:enable='gte(t,{footage:.3f})'[vout]")

        Path(out).parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([
            'ffmpeg', '-y', '-loglevel', 'error',
            '-ss', f'{offset:.3f}', '-t', f'{footage:.3f}', '-i', raw,
            '-loop', '1', '-t', f'{total:.3f}', '-i', str(tmp / 'bg.png'),
            '-loop', '1', '-t', f'{total:.3f}', '-i', str(tmp / 'mask.png'),
            '-loop', '1', '-t', f'{total:.3f}', '-i', str(tmp / 'shadow.png'),
            '-loop', '1', '-t', f'{END_SECONDS:.3f}', '-i', str(tmp / 'end.png'),
            '-i', str(tmp / 'audio.wav'),
            '-filter_complex', ';'.join(g), '-map', '[vout]', '-map', '5:a',
            '-c:v', 'libx264', '-profile:v', 'high', '-pix_fmt', 'yuv420p', '-r', '30',
            '-b:v', '12M', '-maxrate', '16M', '-bufsize', '24M',
            '-c:a', 'aac', '-b:a', '256k', '-movflags', '+faststart',
            '-t', f'{total:.3f}', out,
        ], check=True)
    print(f'{out}: {total:.1f}s, {len(taps)} taps, scenes: ' + ', '.join(f'{n}@{s:.1f}' for s, n in timeline))


if __name__ == '__main__':
    build(*sys.argv[1:4])
