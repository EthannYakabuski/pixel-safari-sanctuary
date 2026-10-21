# Illustrated source assets

The accepted app icon and feature illustration, 23 achievement badges, five leaderboard emblems and eight biome backgrounds were generated as individual raster illustrations with the built-in imagegen tool. `round-two-manifest.json` maps every accepted original and exact prompt to its packaged output. Originals are retained unchanged; final store badges are 512x512, the feature is 1024x500, and runtime biome textures are 768x768. PNG dimensions and hashes are verified during packaging.

The runtime foreground retains the supplied Creature Mixer sprites and Kenney Tiny Town props. Existing character-design/custom asset terms and third-party notices remain in force; the new images do not relabel Creature Mixer artwork as CC0. Full-resolution marketing provenance is excluded from Android/Web exports. Only optimized runtime textures and the launcher icon enter those builds.

The old `marketing/generate_assets.py` predates this illustrated artwork and must not be rerun over the approved files. These prompt/output records preserve provenance; image generation is not claimed to be deterministic. Keep later replacements versioned and review actual store sizes and game scenes before updating the manifest.
