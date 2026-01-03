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
        * If a reference screenshot exists: Analyze it to determine the exact grid, header styles, and footer layout. Prioritize this over the Markdown structure if they differ.
        * If no screenshot exists: Use the Markdown structure and the extracted color palette to infer a professional, "clean" design (e.g., Report Card, Test, Lesson Plan).

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
