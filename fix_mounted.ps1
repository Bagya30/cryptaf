$output = Get-Content analyze_output.txt | Select-String "use_build_context_synchronously"
$fixes = @{}

foreach ($match in $output) {
    if ($match.Line -match "lib\\(.+?\.dart):(\d+):") {
        $file = "lib\" + $matches[1]
        $line = [int]$matches[2]
        
        if (-not $fixes.ContainsKey($file)) {
            $fixes[$file] = @()
        }
        if ($fixes[$file] -notcontains $line) {
            $fixes[$file] += $line
        }
    }
}

foreach ($file in $fixes.Keys) {
    $linesToFix = $fixes[$file] | Sort-Object -Descending
    $content = Get-Content $file -Encoding UTF8
    
    foreach ($lineNum in $linesToFix) {
        $index = $lineNum - 1
        $targetLine = $content[$index]
        $indentMatch = $targetLine -match "^(\s*)"
        $indent = $matches[1]
        
        # Avoid duplicate insertions
        if ($index -gt 0 -and $content[$index-1] -match "if \(!mounted\) return;") {
            continue
        }
        
        $newLine = $indent + "if (!mounted) return;"
        
        # Create new array
        $newContent = @()
        if ($index -gt 0) { $newContent += $content[0..($index-1)] }
        $newContent += $newLine
        $newContent += $content[$index..($content.Length-1)]
        $content = $newContent
    }
    
    $content | Set-Content $file -Encoding UTF8
}
