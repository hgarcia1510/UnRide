$ErrorActionPreference = 'Stop'

$source = Join-Path (Get-Location) 'DOCUMENTACION_UNIRAITE_AVANCE_60.md'
$output = Join-Path (Get-Location) 'Documentacion_UniRaite_Avance_60.docx'
$preview = Join-Path (Get-Location) '.tmp\Documentacion_UniRaite_Avance_60_preview.pdf'

if (-not (Test-Path -LiteralPath $source)) { throw "No existe el Markdown fuente: $source" }
$previewDir = Split-Path -Parent $preview
New-Item -ItemType Directory -Force -Path $previewDir | Out-Null

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$doc = $word.Documents.Add()
$selection = $word.Selection
$selection.Font.Name = 'Aptos'
$selection.Font.Size = 10.5

$page = $doc.Sections.Item(1).PageSetup
$page.TopMargin = $word.InchesToPoints(0.72)
$page.BottomMargin = $word.InchesToPoints(0.72)
$page.LeftMargin = $word.InchesToPoints(0.78)
$page.RightMargin = $word.InchesToPoints(0.78)
$page.PaperSize = 2
$page.DifferentFirstPageHeaderFooter = $true

function Remove-Markup([string]$value) {
  return ($value -replace '\*\*(.*?)\*\*', '$1' -replace '`([^`]+)`', '$1').Trim()
}

function Add-InlineText([string]$value) {
  $regex = [regex]'(\*\*.+?\*\*|`[^`]+`)'
  $position = 0
  foreach ($match in $regex.Matches($value)) {
    if ($match.Index -gt $position) {
      $selection.Font.Bold = 0
      $selection.Font.Name = 'Aptos'
      $selection.Font.Size = 10.5
      $selection.TypeText($value.Substring($position, $match.Index - $position))
    }
    if ($match.Value.StartsWith('**')) {
      $selection.Font.Bold = -1
      $selection.Font.Name = 'Aptos'
      $selection.Font.Size = 10.5
      $selection.TypeText($match.Value.Substring(2, $match.Value.Length - 4))
    } else {
      $selection.Font.Bold = 0
      $selection.Font.Name = 'Consolas'
      $selection.Font.Size = 9
      $selection.Font.Color = 5263440
      $selection.TypeText($match.Value.Substring(1, $match.Value.Length - 2))
    }
    $position = $match.Index + $match.Length
  }
  if ($position -lt $value.Length) {
    $selection.Font.Bold = 0
    $selection.Font.Name = 'Aptos'
    $selection.Font.Size = 10.5
    $selection.Font.Color = 0
    $selection.TypeText($value.Substring($position))
  }
  $selection.Font.Bold = 0
  $selection.Font.Name = 'Aptos'
  $selection.Font.Size = 10.5
  $selection.Font.Color = 0
}

function Add-Paragraph([string]$value, [int]$styleId = -1, [bool]$center = $false) {
  $selection.Style = $doc.Styles.Item($styleId)
  $selection.ParagraphFormat.SpaceAfter = 6
  $selection.ParagraphFormat.WidowControl = $true
  if ($center) { $selection.ParagraphFormat.Alignment = 1 } else { $selection.ParagraphFormat.Alignment = 0 }
  if ($styleId -eq -63) {
    $selection.Font.Name = 'Aptos Display'
    $selection.Font.Size = 27
    $selection.Font.Bold = -1
    $selection.Font.Color = 0
    $selection.Font.Underline = 0
    $selection.ParagraphFormat.SpaceAfter = 10
  } elseif ($styleId -eq -75) {
    $selection.Font.Name = 'Aptos'
    $selection.Font.Size = 17
    $selection.Font.Bold = 0
    $selection.Font.Color = 1849178
    $selection.ParagraphFormat.SpaceAfter = 18
  } elseif ($styleId -eq -2) {
    $selection.Font.Name = 'Aptos Display'
    $selection.Font.Size = 16
    $selection.Font.Bold = -1
    $selection.Font.Color = 1849178
    $selection.ParagraphFormat.SpaceBefore = 10
    $selection.ParagraphFormat.SpaceAfter = 5
    $selection.ParagraphFormat.KeepWithNext = $true
  } elseif ($styleId -eq -3) {
    $selection.Font.Name = 'Aptos Display'
    $selection.Font.Size = 12.5
    $selection.Font.Bold = -1
    $selection.Font.Color = 3158064
    $selection.ParagraphFormat.SpaceBefore = 7
    $selection.ParagraphFormat.SpaceAfter = 4
    $selection.ParagraphFormat.KeepWithNext = $true
  }
  Add-InlineText $value
  $selection.TypeParagraph()
}

function Add-Table([System.Collections.Generic.List[object]]$rows) {
  if ($rows.Count -eq 0) { return }
  $columns = 0
  foreach ($row in $rows) { if ($row.Count -gt $columns) { $columns = $row.Count } }
  $range = $selection.Range
  $table = $doc.Tables.Add($range, $rows.Count, $columns)
  $table.Borders.Enable = 1
  $table.AutoFitBehavior(2)
  $table.Range.Font.Name = 'Aptos'
  $table.Range.Font.Size = 9
  $table.Range.ParagraphFormat.SpaceAfter = 2
  $table.Range.ParagraphFormat.SpaceBefore = 1
  for ($r = 0; $r -lt $rows.Count; $r++) {
    for ($c = 0; $c -lt $columns; $c++) {
      $cellText = ''
      if ($c -lt $rows[$r].Count) { $cellText = Remove-Markup ([string]$rows[$r][$c]) }
      $cell = $table.Cell($r + 1, $c + 1)
      $cell.Range.Text = $cellText
      if ($r -eq 0) {
        $cell.Shading.BackgroundPatternColor = 1849178
        $cell.Range.Font.Color = 16777215
        $cell.Range.Font.Bold = -1
      } else {
        $cell.Shading.BackgroundPatternColor = 16777215
        $cell.Range.Font.Color = 3158064
      }
    }
  }
  $selection.SetRange($table.Range.End, $table.Range.End)
  $selection.TypeParagraph()
  $selection.Style = $doc.Styles.Item(-1)
}

function Add-ProgressTable {
  Add-Paragraph 'Avance global reportado: 60 %' -styleId -1 -center $true
  $range = $selection.Range
  $table = $doc.Tables.Add($range, 1, 10)
  $table.Borders.Enable = 0
  $table.AutoFitBehavior(2)
  $table.Rows.Height = 15
  for ($c = 1; $c -le 10; $c++) {
    $cell = $table.Cell(1, $c)
    $cell.Range.Text = ' '
    if ($c -le 6) { $cell.Shading.BackgroundPatternColor = 1849178 }
    else { $cell.Shading.BackgroundPatternColor = 15132390 }
  }
  $selection.SetRange($table.Range.End, $table.Range.End)
  $selection.TypeParagraph()
  $selection.ParagraphFormat.Alignment = 1
  $selection.Font.Name = 'Aptos'
  $selection.Font.Size = 9
  $selection.Font.Color = 8421504
  $selection.TypeText('60 % documentado  |  40 % pendiente de completar y validar')
  $selection.TypeParagraph()
  $selection.Font.Color = 0
}

$lines = Get-Content -LiteralPath $source -Encoding UTF8
$inCode = $false
$codeLang = ''
$codeLines = New-Object 'System.Collections.Generic.List[string]'
$tableLines = New-Object 'System.Collections.Generic.List[object]'
$titleCount = 0
$pastCover = $false

function Flush-Table {
  if ($tableLines.Count -gt 0) {
    Add-Table $tableLines
    $tableLines.Clear()
  }
}

function Flush-Code {
  if ($codeLines.Count -gt 0) {
    if ($codeLang -eq 'mermaid') {
      Add-Paragraph 'Usuario  ->  Aplicacion Flutter  ->  API REST Node.js y Express  ->  MySQL 8' -styleId -1 -center $false
      Add-Paragraph 'La API valida la sesion y las reglas de negocio antes de consultar o actualizar los datos.' -styleId -1 -center $false
    } else {
      foreach ($codeLine in $codeLines) {
        $selection.Style = $doc.Styles.Item(-1)
        $selection.Font.Name = 'Consolas'
        $selection.Font.Size = 9
        $selection.Font.Color = 5263440
        $selection.ParagraphFormat.LeftIndent = $word.InchesToPoints(0.2)
        $selection.ParagraphFormat.SpaceAfter = 1
        $selection.TypeText($codeLine)
        $selection.TypeParagraph()
        $selection.ParagraphFormat.LeftIndent = 0
      }
    }
    $codeLines.Clear()
  }
}

for ($i = 0; $i -lt $lines.Count; $i++) {
  $line = [string]$lines[$i]
  if ($line -match '^```(.*)$') {
    if (-not $inCode) { Flush-Table; $inCode = $true; $codeLang = $Matches[1].Trim().ToLowerInvariant(); $codeLines.Clear() }
    else { Flush-Code; $inCode = $false; $codeLang = '' }
    continue
  }
  if ($inCode) { $codeLines.Add($line); continue }

  if ($line -match '^\|') {
    $parts = @($line.Trim().Trim('|') -split '\|') | ForEach-Object { $_.Trim() }
    if ($line -notmatch '^\|\s*[-:| ]+\s*\|$') { $tableLines.Add($parts) }
    continue
  }
  Flush-Table
  if ([string]::IsNullOrWhiteSpace($line)) { continue }

  if ($line -match '^#\s+(.+)$') {
    $titleCount++
    Add-Paragraph (Remove-Markup $Matches[1]) -styleId -63 -center $true
    continue
  }
  if ($line -match '^##\s+(.+)$') {
    $heading = Remove-Markup $Matches[1]
    if ($heading -eq 'Resumen' -and -not $pastCover) {
      $selection.InsertBreak(7)
      $pastCover = $true
    }
    if ($titleCount -eq 1 -and -not $pastCover) {
      Add-Paragraph $heading -styleId -75 -center $true
      continue
    }
    Add-Paragraph $heading -styleId -2 -center $false
    continue
  }
  if ($line -match '^###\s+(.+)$') { Add-Paragraph (Remove-Markup $Matches[1]) -styleId -3 -center $false; continue }
  if ($line -match '^\*\*Avance presentado:\*\*') { Add-ProgressTable; continue }
  if ($line -match '^\s*-\s+(.+)$') { Add-Paragraph (Remove-Markup $Matches[1]) -styleId -49 -center $false; continue }
  if ($line -match '^\s*\d+\.\s+(.+)$') {
    $text = $line.Trim() -replace '^\d+\.\s+', ''
    $selection.Style = $doc.Styles.Item(-1)
    $selection.ParagraphFormat.LeftIndent = $word.InchesToPoints(0.25)
    $selection.ParagraphFormat.FirstLineIndent = -$word.InchesToPoints(0.25)
    Add-Paragraph $line.Trim() -styleId -1 -center $false
    $selection.ParagraphFormat.LeftIndent = 0
    $selection.ParagraphFormat.FirstLineIndent = 0
    continue
  }
  Add-Paragraph $line.Trim() -styleId -1 -center ($titleCount -gt 0 -and -not $pastCover)
}
Flush-Table
if ($inCode) { Flush-Code }

$section = $doc.Sections.Item(1)
$footer = $section.Footers.Item(1).Range
$footer.Text = 'UniRaite  |  Documentacion parcial al 60 %  |  Pagina '
$footer.ParagraphFormat.Alignment = 2
$footer.Font.Name = 'Aptos'
$footer.Font.Size = 8
$footer.Font.Color = 8421504
$footer.Collapse(0)
$doc.Fields.Add($footer, 33) | Out-Null
$section.Footers.Item(2).Range.Text = ''

$doc.SaveAs2($output, 12)
$doc.ExportAsFixedFormat($preview, 17)
$doc.Close(0)
$word.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($selection) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($doc) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
[GC]::Collect()
[GC]::WaitForPendingFinalizers()

Get-Item -LiteralPath $output, $preview | Select-Object FullName, Length
