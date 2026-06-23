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
        
        # We inserted before the index. But wait, if we process them descending, 
        # the first line we inserted is at $index, pushing the original line down.
        # So the inserted line is currently at $index!
        if ($content[$index] -match "if \(!mounted\) return;") {
            # Remove it
            $newContent = @()
            if ($index -gt 0) { $newContent += $content[0..($index-1)] }
            if ($index+1 -lt $content.Length) { $newContent += $content[($index+1)..($content.Length-1)] }
            $content = $newContent
        }
    }
    
    $content | Set-Content $file -Encoding UTF8
}
