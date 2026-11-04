$ErrorActionPreference = 'Stop'
$source = Join-Path (Get-Location) '.tmp\Documentacion_UniRaite_Avance_60.html'
$output = Join-Path (Get-Location) 'Documentacion_UniRaite_Avance_60.docx'
$preview = Join-Path (Get-Location) '.tmp\Documentacion_UniRaite_Avance_60_preview.pdf'
$word = $null
$doc = $null
try {
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $word.DisplayAlerts = 0
  $doc = $word.Documents.Open($source, $false, $false)
  $page = $doc.Sections.Item(1).PageSetup
  $page.TopMargin = $word.InchesToPoints(0.72)
  $page.BottomMargin = $word.InchesToPoints(0.72)
  $page.LeftMargin = $word.InchesToPoints(0.78)
  $page.RightMargin = $word.InchesToPoints(0.78)
  $page.PaperSize = 2
  $page.DifferentFirstPageHeaderFooter = $true
  $footer = $doc.Sections.Item(1).Footers.Item(1).Range
  $footer.Text = 'UniRaite  |  Documentación parcial al 60 %  |  Página '
  $footer.ParagraphFormat.Alignment = 2
  $footer.Font.Name = 'Aptos'
  $footer.Font.Size = 8
  $footer.Font.Color = 8421504
  $footer.Collapse(0)
  $doc.Fields.Add($footer, 33) | Out-Null
  $doc.Sections.Item(1).Footers.Item(2).Range.Text = ''
  $doc.SaveAs2($output, 12)
  $doc.ExportAsFixedFormat($preview, 17)
  $doc.Close(0)
  $doc = $null
  $word.Quit()
  $word = $null
  Get-Item -LiteralPath $output, $preview | Select-Object FullName, Length
} finally {
  if ($doc -ne $null) { try { $doc.Close(0) } catch {} }
  if ($word -ne $null) { try { $word.Quit() } catch {} }
}