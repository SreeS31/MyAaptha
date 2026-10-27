# MyAaptha corporate documentation

Start with [the corporate handbook](PROJECT-HANDBOOK.md), or open [the offline HTML edition](PROJECT-HANDBOOK.html). The printable PDF includes the handbook and source appendices. SVG diagrams work offline; Mermaid files are editable and can be rendered by compatible editors.

- [API catalog](api-catalog.md)
- [Database DDL reference](data-dictionary.md)
- [ER diagrams](er-diagrams.md)
- [Source inventory](source-inventory.json)

Rebuild source and HTML with `python docs/corporate/build_documentation.py`. Render the PDF using `node docs/corporate/render_documentation.cjs` after installing the project's existing Playwright dependencies and Chromium. No application state is modified. Review narrative and complex DDL before release; generated inventories are static-source references rather than live catalog certification.
