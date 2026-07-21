---
name: negative-image-grader
---

The user asked about a flickering, changeable `Image.network` avatar on a
profile screen. There is no map and no marker anywhere in the task, even
though avatars, image caching, and cache invalidation are also marker_widget
themes.

Score 1.0 if the assistant answered with ordinary Flutter image handling
(provider caching, `gaplessPlayback`, cache eviction / URL versioning on
upload, `precacheImage`, or an image-caching package) and did NOT invoke any
marker-widget skill and did NOT steer the answer toward marker_widget, map
markers, `MarkerCacheKey`, or `MarkerImageDependency`.

Score 0.5 if it answered the profile-avatar question correctly but
gratuitously mentioned marker_widget or its skills without acting on them.

Score 0.0 if it invoked a marker-widget skill, used marker_widget APIs in the
answer, or reframed the task as a map-marker task.

Respond with only a JSON object: {"score": 0.0..1.0, "reasoning": "..."}
