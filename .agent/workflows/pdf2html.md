---
description: Converts a standardized PDF output folder (Markdown + Artifacts) into a high-fidelity HTML/CSS representation.
---

1. **Analyze Target Context**
    * Identify the target folder provided by the user (e.g., `diversos/PDFs/arquivos_portal/saidas/[Folder-Name]`).
    * Check for the existence of `folder_inspector.py` in the parent directory. If missing, create it to handle color extraction and file listing.
    * **Crucial**: Check if there are any screenshots (e.g., `*.png`, `*.jpg`) *directly* inside the target folder (not just inside `_artifacts`). These are often reference images (screenshots of the original PDF) provided by the user to ensure layout accuracy.

2. **Inspect and Plan**
    * Run `python folder_inspector.py "[Target Folder Path]"` to get the file structure and dominant color palette.
    * Read the content of the converted Markdown file (`.md`) to understand the text and logical structure.
    * **Layout Strategy**:
        * **CRITICAL**: Do NOT embed full-page screenshots (e.g., A4 aspect ratio images) directly into the HTML. These are *reference only*.
        * **Artifact Usage**:
            * Use artifacts to extract:
                * *Color Palette*: Sample colors for borders, headers, and backgrounds.
                * *Structure*: Mimic the visual layout (grids, tables) using HTML/CSS.
            * **Embedding Rule**: Only embed artifacts if they are clearly distinct illustrations (e.g., small icons, photos, diagrams) and NOT full-page renders.
            * *Heuristic*: If an image is large (near A4 size/ratio) and sequential, treat it as a Reference. If it is small or irregular, treat it as Content.
        * If the Markdown text is missing/empty:
            * Do NOT fallback to images.
            * Create a skeleton HTML structure (e.g., empty tables, headers) matching the visual reference.
            * Add a placeholder/warning in the HTML: "Text content could not be extracted. Layout structure preserved."

3. **Generate HTML (Pure CSS Focus)**
    * Create a single HTML file named `[Folder-Name].html` inside the target folder.
    * **Styling Rules**:
        * Use the extracted palette (e.g., `#ee343b`, `#00aeef`) for borders, backgrounds, and headers.
        * **Do not embed artifact images** directly (`<img src="...">`) unless absolutely necessary for logos that cannot be recreated with CSS text/shapes. The goal be lightweight and efficient.
        * Use CSS Grid/Flexbox to mimic complex PDF layouts (tables, forms, columns).
    * **Content**:
        * Map the Markdown text to semantic HTML (`<h1>`, `<table>`, `<div class="field">`).
        * Include form fields (lines, checkboxes) using CSS borders.

4. **Verify**
    * Confirm the file is created.
    * Notify the user with the path to the summary and the result.
