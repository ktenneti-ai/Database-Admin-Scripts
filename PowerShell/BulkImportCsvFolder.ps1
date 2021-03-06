$server = $args[0]
$database = $args[1]
$path = $args[2]
$table1 = @()
$table2 = @()
$count = 0
$pct = 0.0 
$loop = 1 
$prev = 0 
$prog = 1
$query = ""

$table1 = gci $path | Select-Object name | Where-Object {$_.Name -like "*.csv"}
$table2 = Invoke-Sqlcmd -ServerInstance . -Database Rac_azure_Powershell -Query "select name from sys.tables"
for ($i = 0; $i -lt $table1.count; $i++)
{
if($table2.name -match $table1[$i].name.Substring(0,$table1[$i].name.Length-4))	
    {
		$count++
	}
}
$count = $table1.count - $count
'Total files to import are '+$count
$pct = 100 / ($count)
$path_array = $path.ToCharArray()
$slash = $path_array[-1]
for ($i = 0; $i -lt $table1.count; $i++)
{
    if(($table2 | where-object {$_.Name -eq $table1[$i].name.Substring(0,$table1[$i].name.Length-4)}).count -eq 0)	
    {
        if($slash -match "\\")
        {
            $filename =  $path+$table1[$i].Name 
        }
        else
        {
            $filename =  $path+"\"+$table1[$i].Name 
        }
        $query = 'exec [dbo].[BulkImportCsvFile] '''+ $filename +''' , 2'
        Invoke-Sqlcmd -ServerInstance $server -Database $database -Query  $query
        $prog = [Math]::Ceiling($pct * $loop)
        if ($prev -ne $prog)
        {
            $prog.ToString()+"%";
        }
        $loop ++
        $prev = $prog
    }
}
