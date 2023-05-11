import markdown as _md

from markdown_include.include import MarkdownInclude as _MarkdownInclude
from typing import IO as _IO
from pathlib import Path as _Path
from weasyprint import HTML as _HTML

# Attribution:
# to_html() and to_pdf() are adapated from ljpengelen's md2pdf.py
# https://github.com/ljpengelen/markdown-to-pdf/blob/master/md2pdf.py


def to_html(
    markdown: str | _Path | _IO,
    css: str | _Path | _IO,
    include_path: str | _Path,
    encoding: str = "utf-8",
) -> str | None:
    """
    Convert markdown to HTML.

    Args:
        markdown (str | _Path | _IO): The markdown to convert.
        css (str | _Path | _IO): The CSS to use when converting the markdown.
        include_path (str | _Path): The directory to use when resolving includes.

    Returns:
        str | None: The HTML if `output` is None, otherwise None.
    """
    html: str = ""

    # Load the markdown
    markdown_data: str = ""
    if isinstance(markdown, str):
        markdown_data = markdown
    elif isinstance(markdown, _Path):
        with open(markdown, "r") as f:
            markdown_data = f.read()
    elif isinstance(markdown, _IO):
        markdown_data = markdown.read()

    # Load the CSS
    css_data: str = ""
    if isinstance(css, str):
        css_data = css
    elif isinstance(css, _Path):
        with open(css, "r") as f:
            css_data = f.read()
    elif isinstance(css, _IO):
        css_data = css.read()

    # Load the include settings
    include_kwargs: dict = {}
    if include_path:
        include_kwargs["base_path"] = include_path
    if encoding:
        include_kwargs["encoding"] = encoding
    markdown_include: _MarkdownInclude = _MarkdownInclude(**include_kwargs)

    html = markdown.markdown(markdown_data, extensions=[markdown_include])

    return f"""
        <html>
            <head>
                <style rel="stylesheet" type="text/css">
                    {css_data}
                </style>
            </head>
            <body>
                {html}
            </body>
        </html>
    """


def to_pdf(
    markdown: str | _Path | _IO,
    output: str | _Path | _IO,
    css: str | _Path | _IO,
    **kwargs,
) -> None:
    """
    Convert markdown to PDF.

    Args:
        markdown (str | _Path | _IO): The markdown to convert.
        output (_Path | _IO): The output file to write the PDF to.
        css (str | _Path | _IO): The CSS to use when converting the markdown.
        **kwargs: Additional keyword arguments to pass to weasyprint.HTML.
    """
    if isinstance(markdown, (str, _Path)):
        with open(markdown, "r") as f:
            markdown = f.read()
    if isinstance(css, (str, _Path)):
        with open(css, "r") as f:
            css = f.read()
    HTML(string=markdown, base_url=".").write_pdf(output, stylesheets=[css], **kwargs)
