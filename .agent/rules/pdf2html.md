---
trigger: manual
---

# PDF to HTML Conversion Rules

1. **Input Structure Integrity**:
    * You will always be working within a specific structure: `saidas/[Folder_Name]`.
    * Inside this folder, expect:
        * `[Folder_Name].pdf` (Original)
        * `[Folder_Name].md` (Converted Text)
        * `[Folder_Name]_artifacts/` (Extracted Images)
        * *(Optional)* `*.png/jpg` (User-provided screenshots of the PDF page).

2. **Visual Fidelity Logic**:
    * **Primary Reference**: If a generic screenshot (screengrab) of the PDF page exists in the root of the target folder, **YOU MUST** use it as the primary source of truth for the layout (grids, placement, proportions).
    * **Secondary Reference**: If no screenshot exists, rely on the Markdown structure and the `folder_inspector.py` palette extraction.
    * **Palette**: Always adhere strictly to the extracted hex codes for branding (Headers, Borders, Fonts).

3. **Implementation Constraints (Pure CSS)**:
    * **Avoid IMG Tags**: Do not simply link to the extracted artifacts (`image_000...png`) unless they are complex illustrations or photos.
    * **Recreate with CSS**:
        * Logos/Branding: If it's simple text (e.g., "WIZKIDS", "Connections"), recreate it using `<span>` with colored text and specific fonts.
        * Shapes: Use `border-radius`, `box-shadow`, and `background-color` to assume the visual weight of the original PDF design.
    * **Fonts**: Use standard, clean system fonts that match the vibe (e.g., `Segoe UI`, `Arial`, `Comic Sans` for kids) to keep the file standalone and fast.

4. **Automation Script**:
    * Always rely on the `folder_inspector.py` script to "see" the folder content and extracted colors before generating code. This ensures you don't guess the colors.

5. **Output**:
    * The final artifact is always a single `.html` file placed in the same directory as the source files.
    * The HTML must use internal `<style>` blocks (no external CSS files).