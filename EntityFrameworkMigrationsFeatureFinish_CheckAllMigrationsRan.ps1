cls 

$migrationFolder = "C:\work\slate.iva\src\Slate.Iva.Data\Migrations"
$database = "SlateIva"

cd $migrationFolder

$branchMigrations = ls $migrationFolder -Name #all files
$branchMigrations = $branchMigrations -like "*_*.cs" -notlike "*.Designer.cs" #all .cs files

$latestBranchMigration = $branchMigrations | Select-Object -Last 1

$branchCount = $branchMigrations.Length;

Write-Host "Latest branch migration: " ($latestBranchMigration -replace ".cs", "")


$devMigrations = git ls-tree develop --name-only
$devMigrations = $devMigrations -like "*_*.cs" -notlike "*.Designer.cs" #all .cs files

$latestDevMigration = $devMigrations | Select-Object -Last 1
Write-Host "Latest dev migration: " ($latestDevMigration -replace ".cs", "")

$diff = Compare-Object -ReferenceObject ($branchMigrations) -DifferenceObject ($devMigrations) -PassThru

write "branch differences: "
write $diff

if($diff.Length -ne 0){
    write $diff.Length + " differences found"
}

if($branchMigrations.Length -ne $devMigrations.Length){
    #user has new migrations on branch
    Write-Host "Dev migrations: " $devMigrations.Length
    Write-Host "Branch migrations: " $branchMigrations.Length

    if($latestDevMigration -eq $latestBranchMigration){
        #user has added migrations but develop migrations are newer, model will be broken! 
        write-error "new migrations from develop are newer then your branch migrations, please recreate your branch migration"
        exit 1;
    }
        
} else {
    #migration count matches develop
    #possible that 1 added + 1 deleted
    #exit 0;
}

function Invoke-SQL {
    $dataSource = ".";
    $sqlCommand = "SELECT count(*) as MigrationCount from dbo.__MigrationHistory";

    $connectionString = "Data Source=$dataSource; " +
            "Integrated Security=SSPI; " +
            "Initial Catalog=$database"

    #Write-Host $connectionString
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $command = New-Object System.Data.SqlClient.SqlCommand($sqlCommand,$connection)
    #return 
    $connection.Open()

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null

    $connection.Close()
    $dataSet.Tables
}

#test your migrations work by checking the db
$query = Invoke-SQL
$dbCount = $query.Rows[0].MigrationCount
Write-Host "branch has $branchCount migrations"
Write-Host "database has $dbCount migrations"

if ($dbCount -ne $branchCount)
{
    Write-Error "You have unran migrations on your branch. Run them into your database before finishing this branch"
    #throw $error
}
