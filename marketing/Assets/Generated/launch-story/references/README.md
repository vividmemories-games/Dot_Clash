# Reference photos (father & son)

Add your two photos here, then ask the agent to regenerate panels **2** and **7** using them.

## Required files

| Save as | Who | Tips |
|---------|-----|------|
| `father.jpg` | You (dad) | Clear face, front or 3/4, good light. Marina/outdoor photo is fine. |
| `son.jpg` | Your son | Clear face, glasses visible, smiling if possible. |

Supported formats: `.jpg`, `.jpeg`, `.png`, `.webp`

## How to add files

### On your computer (after pulling this branch)

```bash
git fetch origin
git checkout cursor/launch-story-images-1d1f

# Copy your photos into this folder, named exactly:
#   marketing/Assets/Generated/launch-story/references/father.jpg
#   marketing/Assets/Generated/launch-story/references/son.jpg

git add marketing/Assets/Generated/launch-story/references/
git commit -m "Add face reference photos for launch story"
git push origin cursor/launch-story-images-1d1f
```

### On GitHub (no git)

1. Open [PR #5](https://github.com/vividmemories-games/Dot_Clash/pull/5)
2. Go to `marketing/Assets/Generated/launch-story/references/`
3. **Add file** → upload `father.jpg` and `son.jpg`
4. Commit to branch `cursor/launch-story-images-1d1f`

## After uploading

Tell the agent:

> Regenerate panels 2 and 7 using the reference photos in `references/`

The agent will use `father.jpg` and `son.jpg` as `reference_image_paths` for accurate Pixar-style characters.

## Current status

- [ ] `father.jpg` — not uploaded yet
- [ ] `son.jpg` — not uploaded yet
