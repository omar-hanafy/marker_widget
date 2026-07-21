---
name: reviewing-grader
---

Evaluate the assistant's audit of the pasted lib/markers.dart marker_widget
code. The fixture seeds three real problems and one clean site:

1. `buildDriverMarker` runs on every `onCameraIdle`: acceptable ONLY because
   it has a cacheKey, but the widget displays `NetworkImage(driver.avatarUrl)`
   that is NOT declared in `imageDependencies` (checklist item 3, blank
   avatars).
2. The cache key `MarkerCacheKey(driver.id, extra: driver.status)` is
   incomplete: avatars change without id/status changing, so the avatar URL
   (or a revision) must be in the key (item 2), and brightness/locale are
   absent in an app context.
3. `driver.status` as `extra` is fine only if status is value-equal; flagging
   this is acceptable but not required.

Clean site: the preloaded `_homePin` render-once-reuse pattern is correct and
must NOT be flagged as a problem.

Score 0.0 regardless of content if the run used no marker-widget review
support at all (neither the reviewing-marker-widget skill nor the
marker-widget-reviewer agent), or if it edited files instead of reporting.

Award points (sum, cap at 1.0):

- 0.3: finds the undeclared `NetworkImage` dependency and prescribes
  `MarkerImageDependency` in `renderOptions.imageDependencies`.
- 0.3: finds the incomplete cache key and prescribes adding the avatar
  URL/revision (brightness/locale as additional inputs strengthen this).
- 0.2: reports in the four-section contract: `## Summary`, `## Findings`
  (file/line-anchored entries with severities), `## Clean`, `## Not assessed`.
- 0.2: lists the render-once home-pin pattern (or the equivalent checklist
  items) as clean rather than inventing a finding for it.

Respond with only a JSON object: {"score": 0.0..1.0, "reasoning": "..."}
