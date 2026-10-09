# Website media contract

The homepage and Workbench page prioritize:

1. `workbench-hero.webp` — dominant screenshot of a live Workbench session (ideally at least 1600px wide, dark terminal, visible completion popup and inspector). PNG of the same basename is fine after updating the HTML paths.
2. `terminal-slider.gif` — short, looping terminal interaction clip of the slider moving. Prefer 6–12 seconds, cropped tightly, reduced frame rate, small file size, and text alternatives.

Both assets are optional until delivered. `assets/preview.js` detects whether they exist: it replaces the authored preview with the actual media without broken image icons. Avoid committing terminal history, private file paths, API tokens, machine names or customer data in screenshots.

If GIF size is excessive, provide a WebM/MP4 alternate for reduced bandwidth, keeping a still fallback.
