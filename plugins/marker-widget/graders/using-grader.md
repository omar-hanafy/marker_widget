---
name: using-grader
---

Evaluate the assistant's answer about building widget-rendered coffee-shop markers
with marker_widget.

Score 0.0 regardless of the criteria below if no marker-widget skill was invoked
during the run: a correct-looking answer produced without loading the
`using-marker-widget` skill does not demonstrate that skill triggering works.

Award points (sum, cap at 1.0):

- 0.3: the answer uses the documented 3.x API shapes: an extension call such as
  `toMarker(base: Marker(...))` or `toBitmapDescriptor(...)` with named `context:`
  and `renderOptions:`/`MarkerRenderOptions`.
- 0.25: it sets a `cacheKey` (ideally via `MarkerCacheKey`) and, given the app
  has dark mode, includes brightness among the key inputs. Bonus signal, not
  required: noting that resolved size and pixel ratio are keyed automatically.
- 0.2: it explains or correctly applies the two-layer sizing model: logicalSize in
  render options controls raster size, default `MapBitmapOptions()` displays at that
  logical size (no confusion between the two layers).
- 0.15: it passes `context:` so the card inherits the app theme, or explicitly
  justifies omitting it.
- 0.1: rendering happens outside build/per-frame paths (e.g. when the shop list
  loads), markers stored in state.

Score 0.0 regardless of the above if the answer invents APIs that do not exist in
marker_widget 3.x or tells the user to screenshot widgets via RepaintBoundary keys
placed in the visible tree instead of using the package.

Respond with only a JSON object: {"score": 0.0..1.0, "reasoning": "..."}
