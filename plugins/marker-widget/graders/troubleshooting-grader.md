---
name: troubleshooting-grader
---

Evaluate the assistant's diagnosis of blank avatar areas in marker_widget markers
where the avatar is an `Image.network`.

Award points (sum, cap at 1.0):

- 0.4: correctly identifies the root cause: the widget is captured before the
  network image has decoded (async image not painted at snapshot time), and explains
  why debug sometimes works (timing) rather than calling it a release-mode bug.
- 0.3: primary fix is declaring the avatar's provider in
  `renderOptions.imageDependencies` (the same provider instance the widget
  displays), so the renderer decodes it before capture. Recommending only
  `precacheImage` without `imageDependencies` earns at most half of this bullet
  (it narrows the race but is not the package's guaranteed path).
- 0.2: correctly characterizes the 3.x readiness contract: declared dependencies
  are awaited to full decode and retained until capture (deterministic, no
  delays), and/or notes that a failing provider surfaces as
  `MarkerImageLoadException` instead of a silently blank marker.
- 0.1: does NOT recommend irrelevant changes as the fix (bitmap options, cache
  removal, switching scaling modes, disabling caching).

Score 0.0 if the diagnosis blames release-mode tree shaking, missing internet
permission alone, or Google Maps configuration without identifying the async-image
capture cause, or if the recommended fix relies on APIs that do not exist in 3.x
(`waitForImages`, `initialImageDelay`, `imageRepaintDelay`).

Respond with only a JSON object: {"score": 0.0..1.0, "reasoning": "..."}
