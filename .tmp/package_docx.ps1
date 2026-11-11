$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$source = [System.IO.Path]::GetFullPath('C:\Users\garci\uniraite\.tmp\uniraite_docx_package').TrimEnd('\')
$output = 'C:\Users\garci\uniraite\Documentacion_UniRaite_Avance_60_actualizada.docx'
if (-not (Test-Path -LiteralPath $source)) { throw "No existe el paquete fuente." }
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
$zip = [System.IO.Compression.ZipFile]::Open($output, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse) {
    $relative = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $relative, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
  }
} finally { $zip.Dispose() }
Get-Item -LiteralPath $output | Select-Object FullName, Length, LastWriteTime