# Run the 'tar' command and capture its output
$tarOutput = Invoke-Expression 'tar -tf .\vmtemplates\Rocky-9-Vagrant-VMware.latest.x86_64.box  | findstr .vmx'

# Split the output into an array of lines
$lines = $tarOutput -split "`r`n"

# Convert the lines to a JSON array
$jsonArray = @($lines | ForEach-Object { $_ })

# Convert the JSON array to a JSON string
$jsonString = ConvertTo-Json -InputObject $jsonArray

# Output the JSON string
Write-Output $jsonString
