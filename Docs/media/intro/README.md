# GlideMouse product overview

`glidemouse-intro.mp4` is the landing page's 32-second overview: 1920 × 1080,
30 fps, H.264 video and stereo AAC audio. `poster.jpg` is its opening frame.
`english.vtt` provides optional captions for the English on-screen copy.

The film uses actual SwiftUI captures with isolated sample settings, plus the
existing GlideMouse icon. Focus outlines and camera movement are presentation
graphics. They do not represent a physical mouse test or a recording of macOS
switching desktops. The 0.4.2 button list, scrolling and app-settings captures use sample
settings; no personal configuration is included. The older `source/` files
are preserved for reproducibility and are no longer used by the renderer.

The instrumental soundtrack is an original deterministic synthesis created by
`Scripts/render-intro.py`. It uses no sampled music, external recording,
generated voice, cloud service or paid asset. The music and presentation are
provided under this project's MIT license. Avenir Next is used for rendering
on macOS; no font files are redistributed.

To rebuild locally on macOS, use Python with Pillow and NumPy, and FFmpeg on
your PATH:

```sh
python3 Scripts/render-intro.py
```

The closing call to action is **Download for macOS**. It does not claim Mac
App Store availability. The longer English and Myanmar tutorials remain at
`tutorials.html` and under `Docs/media/videos/`.
