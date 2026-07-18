---
name: troubleshooting-grader
---

Evaluate the assistant's diagnosis of blank avatar areas in marker_widget markers
where the avatar is an `Image.network`.

Award points (sum, cap at 1.0):

- 0.4: correctly identifies the root cause: the widget is rasterized before the
  network image has loaded (async image not painted at snapshot time), and explains
  why debug sometimes works (timing) rather than calling it a release-mode bug.
- 0.3: primary fix is precaching the image (`precacheImage`) before rendering, or
  `waitForImages: true`; ideally recommends precache as the reliable option.
- 0.2: mentions that `waitForImages` is delay-based (initial check plus repaint
  delay, configurable via `imageRepaintDelay`), not a guarantee, or otherwise
  correctly qualifies its reliability for slow networks.
- 0.1: does NOT recommend irrelevant changes as the fix (bitmap options, cache
  removal, switching scaling modes, disabling caching).

Score 0.0 if the diagnosis blames release-mode tree shaking, missing internet
permission alone, or Google Maps configuration, without identifying the async-image
rasterization cause.

Respond with only a JSON object: {"score": 0.0..1.0, "reasoning": "..."}
