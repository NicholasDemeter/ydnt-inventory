PROMPT: YDNT Site — FINAL ALIGNMENT & IMAGE LOADING ONLY (NO NEW STACK)

Objective (read carefully):
This is a near-finished static site that’s been stuck at the images not loading / placeholders phase for too long. Do not propose or add a new stack. Do not generate “ghost” integrations or code paths. Just align to the existing sources of truth and make the images and videos render correctly. The repo is already aligned—respect it.

Hard Constraints (non-negotiable)

Stack: Static HTML/CSS/JS only, deployed via GitHub Pages.

No Supabase, no databases, no Vercel, no frameworks, no admin UI.

No renaming of files/folders, no auto-slugifying, no “helpful” migrations.

Sources of truth (SOT):

Local/Git repo (canonical): /Users/nicholasdemeter/Documents/youdontneedthis-inventory
(Public repo: https://github.com/NicholasDemeter/youdontneedthis-inventory, site: https://www.youdontneedthis.us/)

Google Sheet (read-only metadata catalog):
ID: 1Pp6bvp4DoDJqVKIrNuN9N6zS_MhVex9UDRSC-nIGI6k
The Sheet is the only dynamic catalog (titles, scores, ordering, etc.). Read-only. Do not write back.

Folder structure per LOT (must remain exactly as is):
LOT-###/Photos/ (images + thumb.jpg), LOT-###/Videos/ (0–1 video).
Images must load from /Photos/; videos from /Videos/. Keep relative paths valid for GitHub Pages.

Previous misfires to avoid: Do not connect to Supabase “just to read the Google Sheet.” Do not create a mirror DB. Do not regenerate naming conventions. Use what exists.

Deliverables

Working image & video rendering across all LOT pages and the index grid.

Thumbnails (thumb.jpg) show in the grid.

Clicking a LOT opens a gallery that includes images and (if present) the single video (autoplay on click is fine).

No flicker when cycling images.

Zero 404s: No broken src/href in DevTools for images/videos.

Asset Audit Report (single file in repo root):

CSV or JSON: lot_id, missing_thumb, missing_photos_count, videos_count, broken_paths[].

This must reflect the actual repo state, not guesses.

Minimal patch: A single PR (or patch set) with a short CHANGELOG.md explaining exactly what changed and why.

Sheet wiring: Read the metadata from the provided Google Sheet only as a read-only catalog to drive ordering/labels. If network is unavailable, site must still render assets from the repo (degrade gracefully, no blank placeholders).

Acceptance Tests (must pass)

On the live build (GitHub Pages):

LOT-047 and LOT-069 show correct thumbnails on the index grid and load their full galleries without flicker.

If a LOT has a video, it appears in the gallery and plays on click.

Price-range button on each LOT is restored (it was removed by mistake previously).

Hero carousel (e.g., LOT-002 showcase) works and displays real assets (no placeholders).

Opening DevTools Console/Network reveals no 404s for LOT media.

If an image file is genuinely missing, the UI shows a small “asset missing” badge for that LOT and the asset appears in the Asset Audit Report. No silent failures.

Implementation Rules

Keep everything relative-path safe for GitHub Pages (no absolute OS paths, no server assumptions).

Do not modify folder names, LOT numbers, or internal filenames.

Do not introduce npm builds, package managers, or bundlers. Keep it portable and offline-friendly.

Use tiny, local JS helpers only if needed (e.g., preloading, debounced image swap) and document in CHANGELOG.md.

If you must touch HTML, make the smallest possible edits. Prefer adding resilient JS that discovers assets in each LOT folder and renders them.

What to Explain Back (short)

Confirm exactly which sheet ranges/fields you read and how you map them to LOT folders (by LOT id).

Confirm how you build gallery lists from /Photos/ and /Videos/ without renaming.

Attach the Asset Audit Report snapshot from your run.

State any LOTs that have real missing assets (by path), so we can fix files—not code.

Reminder

This site is 95% done. The only acceptable outcome is: images/videos render from the aligned repo, driven by the Google Sheet as the catalog, with minimal code changes and zero ghost infrastructure.

If any ambiguity remains, assume the simplest static approach that honors the repo + sheet. Do not invent a new stack.