CREATE Procedure [dbo].[sp_search_backup_files_in_subfolders]
(@location nvarchar(1000) = '\\npci2.d2fs.albilad.com\T24_DB_Backup_Arch\2014-2017')
as
begin
declare 
@xp_cmdshell nvarchar(2000), 
@level int = 0, 
@dynamic_cursor varchar(max),
@first_level int, 
@last_level int, 
@exit bit = 0,
@loc nvarchar(2000), 
@id int

SET NOCOUNT ON
DECLARE @root_folder	table	(output_text nvarchar(max), level_id int, root_folder nvarchar(1000), index inx_level_id (level_id))
DECLARE @folder_content table	(output_text nvarchar(max), id int)
CREATE TABLE #root_folders		(output_text nvarchar(max), level_id int, root_folder nvarchar(1000), index inx_level_id (level_id))
CREATE TABLE #root_files		(id int identity(1,1), backup_file_name nvarchar(3000), [location] nvarchar(2000))

SET @xp_cmdshell = 'xp_cmdshell '+''''+'dir cd '+@location+''''
INSERT INTO #root_folders (output_text)
EXEC (@xp_cmdshell)

UPDATE #root_folders 
   SET level_id = 1, 
	   root_folder = @location 
 WHERE level_id is null

while @exit = 0 
begin
set @level = @level + 1
select @first_level = max(level_id) from #root_folders
set @dynamic_cursor = '
declare @id int, @folder_name nvarchar(1000), @root_folder_name nvarchar(3000), @xp_cmdshell nvarchar(2000)
declare level_s_cursor cursor fast_forward
for
select row_number() over(partition by root_folder order by name) id, name, root_folder
from (
select ltrim(rtrim(substring(output_text, 1, charindex(''>'',output_text)))) [type], ltrim(rtrim(substring(output_text, charindex('' '',output_text), len(output_text)))) [name], level_id, root_folder
from (
select ltrim(rtrim(substring(output_text, charindex(''M '',output_text)+2, len(output_text)))) output_text, '+cast(@level as varchar)+' level_id, root_folder
from #root_folders
where output_text like ''%M %''
and (output_text not like ''%<DIR>%.%'' and output_text not like ''%<DIR>%..%'')
and output_text like ''%<DIR>%''
and level_id > '+cast(@level as varchar)+' - 1)a)b
order by root_folder, id

open level_s_cursor
fetch next from level_s_cursor into @id, @folder_name, @root_folder_name
while @@FETCH_STATUS = 0
begin

set @xp_cmdshell = ''xp_cmdshell '+''''+''''+'dir cd ''+@root_folder_name+''\''+@folder_name+''''''''
insert into #root_folders (output_text)
exec(@xp_cmdshell)

update #root_folders set level_id = '+cast(@level as varchar)+' + 1, root_folder = @root_folder_name+''\''+@folder_name where level_id is null

fetch next from level_s_cursor into @id, @folder_name, @root_folder_name
end
close level_s_cursor
deallocate level_s_cursor'
exec(@dynamic_cursor)
select @last_level = max(level_id) from #root_folders

if @first_level = @last_level
begin
	set @exit = 1
end
end

declare files_cursor cursor fast_forward
for
select id, [path]
from (
select row_number() over(order by root_folder+'\'+name) id, root_folder+'\'+name [path], level_id
from (
select ltrim(rtrim(substring(output_text, 1, charindex('>',output_text)))) [type], ltrim(rtrim(substring(output_text, charindex(' ',output_text), len(output_text)))) [name], level_id, root_folder
from (
select ltrim(rtrim(substring(output_text, charindex('M ',output_text)+2, len(output_text)))) output_text, level_id, root_folder
from #root_folders
where output_text like '%M %'
and (output_text not like '%<DIR>%.%' and output_text not like '%<DIR>%..%')
and output_text like '%<DIR>%')a)b)c
order by id

open files_cursor
fetch next from files_cursor into @id, @loc
while @@FETCH_STATUS = 0
begin

SET @xp_cmdshell = 'xp_cmdshell '+''''+'dir cd '+@loc+''''

INSERT INTO @folder_content (output_text)
EXEC(@xp_cmdshell)

UPDATE @folder_content 
   SET id = @id 
 WHERE id is null

INSERT INTO #root_files (backup_file_name , [location])
select [name], [location]
from (
select [name], @loc [location], id
from (
select ltrim(rtrim(substring(output_text, 1, charindex('>',output_text)))) [type], ltrim(rtrim(substring(output_text, charindex(' ',output_text), len(output_text)))) [name], id
from (
select ltrim(rtrim(substring(output_text, charindex('M ',output_text)+2, len(output_text)))) output_text, id
from @folder_content
where output_text like '%M %'
and (output_text not like '%<DIR>%.%' and output_text not like '%<DIR>%..%')
and output_text not like '%<DIR>%')a)b
where (name like '%.bak' or name like '%.trn'))c
where id = @id

fetch next from files_cursor into @id, @loc
end
close files_cursor
deallocate files_cursor

select id, backup_file_name, [location] 
from #root_files
order by [location], backup_file_name

SET NOCOUNT OFF
end
