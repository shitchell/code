# clip-wsl.ps1 -- Windows-side half of provider.clip.wsl. Not a provider;
# invoked only by provider.clip.wsl as:
#   powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File clip-wsl.ps1 <mode> [paths...]
#
# Deliberately NOT named provider.clip.<something>, and kept non-executable:
# the dispatcher enumerates providers with `compgen -c 'provider.clip.'`, and
# this file must never be mistaken for one.
#
# Content always travels in temp FILES (Windows paths from `wslpath -w`), never
# on the command line: inline -Value hits the ~32K Windows command-line limit
# and needs quoting. Files are read as UTF-8 without BOM.
#
# Modes:
#   set-plain <textPath>
#       Put the text on the clipboard as UnicodeText.
#   set-rich <htmlPath> <textPath>
#       Put ONE data object on the clipboard carrying BOTH a CF_HTML ("HTML
#       Format") built from the fragment in <htmlPath> AND UnicodeText from
#       <textPath>. Paste targets pick the flavour they understand.
#   get-rich
#       Write the HTML fragment currently on the clipboard to stdout as raw
#       UTF-8 bytes (empty if the clipboard holds no HTML). Pure read.
#
# ENCODING TRAPS (all verified 2026-09-24):
#   - CF_HTML must be handed to the DataObject as a MemoryStream of UTF-8 bytes.
#     Passed as a .NET *string*, .NET Framework writes it in the ANSI codepage
#     and every non-ASCII character (e.g. U+2713 check mark) becomes a literal '?'.
#   - On readback, neither GetData("HTML Format") nor Get-Clipboard
#     -TextFormatType Html can be trusted: both decode as the ANSI codepage, so a
#     correct U+2713 reads back as mojibake. get-rich reads the raw bytes via
#     Win32 and writes them straight to the stdout stream (console output
#     encoding is not UTF-8 either).

param(
  [Parameter(Mandatory = $true)][string]$Mode,
  [string]$Path1,
  [string]$Path2
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$enc = New-Object System.Text.UTF8Encoding($false)

function Read-Utf8([string]$p) { [IO.File]::ReadAllText($p, $enc) }

function Build-CfHtml([string]$frag) {
  # CF_HTML: an ASCII header of 10-digit BYTE offsets (over the UTF-8 encoding)
  # followed by an HTML document whose fragment is bracketed by comments.
  $pre  = '<html><body><!--StartFragment-->'
  $post = '<!--EndFragment--></body></html>'
  $hdrT = "Version:0.9`r`nStartHTML:{0:D10}`r`nEndHTML:{1:D10}`r`nStartFragment:{2:D10}`r`nEndFragment:{3:D10}`r`n"
  $sh = $enc.GetByteCount(($hdrT -f 0, 0, 0, 0))
  $sf = $sh + $enc.GetByteCount($pre)
  $ef = $sf + $enc.GetByteCount($frag)
  $eh = $ef + $enc.GetByteCount($post)
  ($hdrT -f $sh, $eh, $sf, $ef) + $pre + $frag + $post
}

function Get-HtmlBytes {
  # Raw CF_HTML bytes straight from the clipboard HGLOBAL, or $null.
  #
  # NOT [Windows.Forms.Clipboard]::GetData("HTML Format"): .NET Framework
  # decodes that with the ANSI codepage, so UTF-8 comes back double-encoded
  # (U+00E9 -> "Ã©") and the byte offsets in the header no longer line up with
  # the string. Win32 GetClipboardData hands us the exact bytes instead.
  Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class ClipWslRaw {
  [DllImport("user32.dll")] static extern bool OpenClipboard(IntPtr h);
  [DllImport("user32.dll")] static extern bool CloseClipboard();
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern uint RegisterClipboardFormat(string n);
  [DllImport("user32.dll")] static extern IntPtr GetClipboardData(uint f);
  [DllImport("kernel32.dll")] static extern IntPtr GlobalLock(IntPtr h);
  [DllImport("kernel32.dll")] static extern bool GlobalUnlock(IntPtr h);
  [DllImport("kernel32.dll")] static extern UIntPtr GlobalSize(IntPtr h);
  public static byte[] Get(string name) {
    uint f = RegisterClipboardFormat(name);
    if (!OpenClipboard(IntPtr.Zero)) return null;
    try {
      IntPtr h = GetClipboardData(f); if (h == IntPtr.Zero) return null;
      int n = (int)GlobalSize(h); IntPtr p = GlobalLock(h); if (p == IntPtr.Zero) return null;
      try { byte[] b = new byte[n]; Marshal.Copy(p, b, 0, n); return b; } finally { GlobalUnlock(h); }
    } finally { CloseClipboard(); }
  }
}
"@
  [ClipWslRaw]::Get('HTML Format')
}

function Get-Fragment([byte[]]$b) {
  # Slice StartFragment..EndFragment by byte offset; fall back to StartHTML..
  # EndHTML, then to everything. Offsets of -1 (allowed by the spec) are ignored.
  $head = [Text.Encoding]::ASCII.GetString($b, 0, [Math]::Min($b.Length, 400))
  foreach ($pair in @(@('StartFragment', 'EndFragment'), @('StartHTML', 'EndHTML'))) {
    $s = [regex]::Match($head, "$($pair[0]):(-?\d+)")
    $e = [regex]::Match($head, "$($pair[1]):(-?\d+)")
    if ($s.Success -and $e.Success) {
      $si = [int]$s.Groups[1].Value; $ei = [int]$e.Groups[1].Value
      if ($si -ge 0 -and $ei -ge $si -and $ei -le $b.Length) {
        $out = New-Object byte[] ($ei - $si)
        [Array]::Copy($b, $si, $out, 0, $ei - $si)
        return $out
      }
    }
  }
  return $b
}

switch ($Mode) {
  'set-plain' {
    $text = Read-Utf8 $Path1
    if ($text.Length -eq 0) { [Windows.Forms.Clipboard]::Clear() }
    else { [Windows.Forms.Clipboard]::SetText($text, [Windows.Forms.TextDataFormat]::UnicodeText) }
  }
  'set-rich' {
    $cf = Build-CfHtml (Read-Utf8 $Path1)
    $text = Read-Utf8 $Path2
    $d = New-Object System.Windows.Forms.DataObject
    $d.SetData([Windows.Forms.DataFormats]::Html, (New-Object IO.MemoryStream(, $enc.GetBytes($cf))))
    if ($text.Length -gt 0) { $d.SetText($text, [Windows.Forms.TextDataFormat]::UnicodeText) }
    # $true = copy: data survives this process exiting.
    [Windows.Forms.Clipboard]::SetDataObject($d, $true)
  }
  'get-rich' {
    $b = Get-HtmlBytes
    if ($b) {
      $f = Get-Fragment $b
      $o = [Console]::OpenStandardOutput(); $o.Write($f, 0, $f.Length); $o.Flush()
    }
  }
  default { [Console]::Error.WriteLine("clip-wsl.ps1: unknown mode: $Mode"); exit 2 }
}
