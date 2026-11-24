# Engram: a knowledge graph that lights up as you learn

A 20-minute talk introducing Engram, live at https://enspyrco.github.io/engram/talks/engram-intro/.

Arrow keys or a click move between slides, `N` shows the speaker notes, `F` goes full screen. `#slide-7` in the address opens slide 7.

## Layout

- `source/deck.json` lists the slides in order, the outline and the typefaces.
- `source/deck.css` holds the shared look.
- `source/slides/<id>.html` is one slide each: a 1920×1080 `<section>`, with its speaker notes in the `<aside>`.
- `index.html`, `viewer.css` and `viewer.js` load those files and scale them to the window. There is no build step: edit a slide, merge, and the published talk changes.

The slides use the Claude Slides format, so the `source/` folder can also be published back into a Slides artifact for editing there.

## Running it locally

`fetch` needs a server rather than a `file://` page:

```bash
python3 -m http.server 8000   # from the repository root
# then open http://localhost:8000/talks/engram-intro/
```
