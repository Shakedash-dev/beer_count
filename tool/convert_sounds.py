#!/usr/bin/env python3
"""Converts the raw clips in sounds/ into the app's rotation.

Each clip is trimmed of leading/trailing silence, downmixed to mono 44.1 kHz,
capped at MAX_SECONDS with a short fade, loudness-matched to TARGET_MEAN_DB
(up to MAX_LIMITING_DB of transient pushed into a limiter at PEAK_CEILING_DB,
so quiet clips come up without clipping) and written as OGG Vorbis to
android/app/src/main/res/raw/beer_sound_N.ogg in filename order.

Requires ffmpeg on PATH. Re-run after adding or removing a clip.
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'sounds')
OUT = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'raw')

MAX_SECONDS = 1.5
FADE_SECONDS = 0.08
TARGET_MEAN_DB = -20.0
PEAK_CEILING_DB = -1.5
MAX_LIMITING_DB = 6.0
EXTS = ('.wav', '.flac', '.aiff', '.aif', '.mp3', '.ogg', '.m4a')

TRIM = (
    'silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.005,'
    'areverse,'
    'silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.02,'
    'areverse'
)


def run(args):
    return subprocess.run(args, capture_output=True, text=True, check=True)


def volume(path, pre_filter):
    err = run(['ffmpeg', '-hide_banner', '-i', path, '-af',
               pre_filter + ',volumedetect', '-f', 'null', '-']).stderr
    mean = float(re.search(r'mean_volume: (\S+) dB', err).group(1))
    peak = float(re.search(r'max_volume: (\S+) dB', err).group(1))
    return mean, peak


def main():
    clips = sorted(p for p in glob.glob(os.path.join(SRC, '*'))
                   if p.lower().endswith(EXTS))
    if not clips:
        sys.exit(f'no clips in {SRC}')
    os.makedirs(OUT, exist_ok=True)
    for old in glob.glob(os.path.join(OUT, 'beer_sound_*.ogg')):
        os.remove(old)

    base = (f'aformat=channel_layouts=mono,aresample=44100,{TRIM},'
            f'atrim=0:{MAX_SECONDS}')
    for i, clip in enumerate(clips, start=1):
        mean, peak = volume(clip, base)
        gain = min(TARGET_MEAN_DB - mean,
                   PEAK_CEILING_DB - peak + MAX_LIMITING_DB)
        dur = float(run(['ffprobe', '-v', 'error', '-show_entries',
                         'format=duration', '-of', 'csv=p=0', clip]).stdout)
        dur = min(dur, MAX_SECONDS)
        fade_at = max(dur - FADE_SECONDS, 0)
        chain = (f'{base},volume={gain:.2f}dB,'
                 f'alimiter=limit={10 ** (PEAK_CEILING_DB / 20):.3f}'
                 f':attack=1:release=30:level=disabled,'
                 f'afade=t=out:st={fade_at:.3f}:d={FADE_SECONDS}')
        out = os.path.join(OUT, f'beer_sound_{i}.ogg')
        run(['ffmpeg', '-hide_banner', '-y', '-i', clip, '-af', chain,
             '-c:a', 'libvorbis', '-q:a', '5', out])
        print(f'{os.path.basename(out)} <- {os.path.basename(clip)} '
              f'(gain {gain:+.1f} dB)')


if __name__ == '__main__':
    main()
