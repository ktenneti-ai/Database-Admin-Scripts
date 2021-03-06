--Create 3 jobs in all instances (primary and secondary) the same
--and put those 3 procedures (Full, Differential, and Transaction log) for each job and name the jobs as it mentained.
--and for each job 3 steps for each step the procedure step number as it below.
--create 2 linked servers or more if you have more secondary instances
--Full backup job is *Full_Backup_Database*
--Differential backup job is *Differential_Backup*
--Transaction Log backup job is *Transaction_Log_Backup*
--about the backup on secondary node this can be happened with the below checks
--1: Full backup Copy_only
--2: Transaction log normal copy_only not supported in Secondary
--3: Differential backups are not supported in the Secondary, but:
--if you are using
--SQL Server 2017 it's allowed to use Differential backups on the secondary for using versions between RTM and CU19, and after that it's not supported.
--SQL Server 2019 it's allowed to use Differential backups on the secondary for using versions between RTM and CU5, and after that it's not supported.
--use Differential backup in the primary node.

USE [Bak_Config]
GO
CREATE PROCEDURE [dbo].[Full_Backup_Databases_step1]
as
begin

declare @is_primary int, @server_number int, @isPrimary bit
select @isPrimary = is_primary 
from Backup_Preferences

select @is_primary = case when name = (select Primary_replica from sys.dm_hadr_availability_group_states) then 1 else 0 end,
@server_number = left(reverse(substring(name,1,charindex('\', name)-1)),1)
from sys.servers
where server_id = 0

IF @is_primary = @isPrimary and @is_primary = 0
begin
	if @server_number = 2
	begin
		exec [AZ-WE-SQL001\AZ_SP_DB].[Bak_Config].[dbo].[sp_jobs_control_v02] @status = 0
		exec [AZ-WE-SQL001\AZ_SP_DB].[Bak_Config].[dbo].[Insert_into_config] @type = 'F'
		exec [AZ-WE-SQL001\AZ_SP_DB].[Bak_Config].[dbo].[reset_sequence] @type = 0
	end
	if @server_number = 1
	begin
		exec [AZ-WE-SQL002\AZ_SP_DB].[Bak_Config].[dbo].[sp_jobs_control_v02] @status = 0
		exec [AZ-WE-SQL002\AZ_SP_DB].[Bak_Config].[dbo].[Insert_into_config] @type = 'F'
		exec [AZ-WE-SQL002\AZ_SP_DB].[Bak_Config].[dbo].[reset_sequence] @type = 0
	end
waitfor delay '00:00:10'
end
else iF @is_primary = @isPrimary and @is_primary = 1
begin
		exec [Bak_Config].[dbo].[sp_jobs_control_v02] @status = 0
		exec [Bak_Config].[dbo].[Insert_into_config] @type = 'F'
		exec [Bak_Config].[dbo].[reset_sequence] @type = 0
waitfor delay '00:00:10'
end
end
GO

CREATE PROCEDURE [dbo].[Full_Backup_Databases_step2]
as
begin
declare @is_primary int, @server_number int, @Backup_Preferences bit
select @Backup_Preferences = is_primary 
from Backup_Preferences

select @is_primary = case when name = (select Primary_replica from sys.dm_hadr_availability_group_states) then 1 else 0 end,
@server_number = left(reverse(substring(name,1,charindex('\', name)-1)),1)
from sys.servers
where server_id = 0

select @is_primary, @Backup_Preferences

IF @is_primary = @Backup_Preferences and @is_primary = 0
begin
                exec [Bak_Config].[dbo].[Backup_Database_v03] @backup_type = 'F', @server_type = @is_primary
                if @server_number = 1
                begin
                   exec  [AZ-WE-SQL002\AZ_SP_DB].[Bak_Config].[dbo].[backup_database] @backup_type = 'F'
                end
                else if @server_number = 2
                begin
                   exec [AZ-WE-SQL001\AZ_SP_DB].[Bak_Config].[dbo].[backup_database] @backup_type = 'F'
                end
end
else if @is_primary = @Backup_Preferences and @is_primary = 1
begin
                exec [Bak_Config].[dbo].[Backup_Database_v03] @backup_type = 'F', @server_type = @is_primary
                if @server_number = 1
                begin
                   exec  [AZ-WE-SQL002\AZ_SP_DB].[Bak_Config].[dbo].[backup_database] @backup_type = 'F'
                end
                else if @server_number = 2
                begin
                   exec [AZ-WE-SQL001\AZ_SP_DB].[Bak_Config].[dbo].[backup_database] @backup_type = 'F'
                end
end
end
GO

CREATE PROCEDURE [dbo].[Full_Backup_Databases_step3]
as
begin
declare @is_primary int, @server_number int, @isPrimary bit
select @isPrimary = is_primary 
from Backup_Preferences
select @is_primary = case when name = (select Primary_replica from sys.dm_hadr_availability_group_states) then 1 else 0 end
from sys.servers
where server_id = 0

select @server_number = left(reverse(substring(name,1,charindex('\', name)-1)),1)
from sys.servers
where server_id = 0

IF @is_primary = @isPrimary and @is_primary = 0
begin
	if @server_number = 2
	begin
	update [AZ-WE-SQL001\AZ_SP_DB].[Bak_Config].[dbo].[config] set 
	backup_end = getdate(), 
	status = 1
	where status = 0
	and backup_type = 'F'

	exec [AZ-WE-SQL001\AZ_SP_DB].[Bak_Config].[dbo].[Delete_Expired_Backup_v02] @backup_type = 'F'
	exec [AZ-WE-SQL001\AZ_SP_DB].[Bak_Config].[dbo].[sp_jobs_control_v02] @jobs = 'All', @status = 1
	exec [AZ-WE-SQL001\AZ_SP_DB].msdb.dbo.sp_start_job @job_name = 'Transaction_Log_Backup'
	end
	else if @server_number = 1
	begin
	update [AZ-WE-SQL002\AZ_SP_DB].[Bak_Config].[dbo].[config] set 
	backup_end = getdate(), 
	status = 1
	where status = 0
	and backup_type = 'F'

	exec [AZ-WE-SQL002\AZ_SP_DB].[Bak_Config].[dbo].[Delete_Expired_Backup_v02] @backup_type = 'F'
	exec [AZ-WE-SQL002\AZ_SP_DB].[Bak_Config].[dbo].[sp_jobs_control_v02] @jobs = 'All', @status = 1
	exec [AZ-WE-SQL002\AZ_SP_DB].msdb.dbo.sp_start_job @job_name = 'Transaction_Log_Backup'
	end
end
else
	begin
	update [Bak_Config].[dbo].[config] set 
	backup_end = getdate(), 
	status = 1
	where status = 0
	and backup_type = 'F'

	exec [Bak_Config].[dbo].[Delete_Expired_Backup_v02] @backup_type = 'F'
	exec [Bak_Config].[dbo].[sp_jobs_control_v02] @jobs = 'All', @status = 1
	exec msdb.dbo.sp_start_job @job_name = 'Transaction_Log_Backup'
end
end
GO

USE [Bak_Config]
GO
CREATE PROCEDURE [dbo].[Differential_Backup_databases_step1]
as
begin
declare @is_primary int

select 
@is_primary = case when name = (select Primary_replica from sys.dm_hadr_availability_group_states) then 1 else 0 end
from sys.servers
where server_id = 0

IF @is_primary = 1
begin
		exec [Bak_Config].[dbo].[sp_jobs_control_v02] @jobs = 'Transaction_Log_Backup', @status = 0
		exec [Bak_Config].[dbo].[Insert_into_Config] @type = 'D'
		exec [Bak_Config].[dbo].[reset_sequence] @type = 2
end
end
GO

CREATE PROCEDURE [dbo].[Differential_Backup_databases_step2]
as
begin
declare @is_primary int

select 
@is_primary = case when name = (select Primary_replica from sys.dm_hadr_availability_group_states) then 1 else 0 end
from sys.servers
where server_id = 0

IF @is_primary = 1
begin
	exec [Bak_Config].[dbo].[backup_database_v03] @backup_type = 'D', @server_type = 1
end
end
GO

CREATE PROCEDURE [dbo].[Differential_Backup_databases_step3]
as
begin
declare @is_primary int, @start_date datetime, @end_date datetime

select 
@is_primary = case when name = (select Primary_replica from sys.dm_hadr_availability_group_states) then 1 else 0 end
from sys.servers
where server_id = 0

IF @is_primary = 1
begin
	update [Bak_Config].[dbo].config set 
	backup_end = getdate(), 
	status = 1
	where status = 0
	and backup_type = 'D'
	
	exec [Bak_Config].[dbo].[Delete_Expired_Backup_v02] @backup_type = 'D'

	select 
	@start_date = dateadd(hour, 1, backup_end),
	@end_date = dateadd(hour, 1 * 23, backup_end)
	from [Bak_Config].[dbo].[config]
	where backup_type = 'D'
	and status = 1
	and backup_start in (select max(backup_start) from (select backup_start, backup_type from config where backup_type = 'D')a)

	--exec [Bak_Config].[dbo].[sp_change_job_schedule_v02] @job_name = 'Transaction_Log_Backup', @start = @start_date, @end = @end_date	
	exec [Bak_Config].[dbo].[sp_jobs_control_v02] @jobs = 'Transaction_Log_Backup', @status = 1
end
end

GO

CREATE PROCEDURE [dbo].[Transaction_Log_Backup_step1]
as
begin
declare @is_primary int, @is_critical int, @server_number int, @isPrimary bit
select @isPrimary = is_primary 
from Backup_Preferences

select 
@is_primary = case when name = (select Primary_replica from sys.dm_hadr_availability_group_states) then 1 else 0 end,
@server_number = left(reverse(substring(name,1,charindex('\', name)-1)),1)
from sys.servers
where server_id = 0

select @is_critical =
case 
when datepart(WEEKDAY, getdate())  = 7 and getdate() < dateadd(hour, 19, convert(datetime,convert(date, getdate(),120),120)) 
then 0
when datepart(WEEKDAY, getdate())  < 7 
then 0 
else 1 end

IF @is_primary = @isPrimary and @is_critical = 0 and @is_primary = 0
begin
	if @server_number = 2
	begin
		IF (select count(*) from [AZ-WE-SQL001\AZ_SP_DB].[Bak_Config].[dbo].[config] where backup_type = 'L' and status = 0) = 0
		Begin
			exec [AZ-WE-SQL001\AZ_SP_DB].[Bak_Config].[dbo].[Insert_into_Config] @type = 'L'
		End
	end
	else if @server_number = 1
	begin
		IF (select count(*) from [AZ-WE-SQL002\AZ_SP_DB].[Bak_Config].[dbo].[config] where backup_type = 'L' and status = 0) = 0
		Begin
			exec [AZ-WE-SQL002\AZ_SP_DB].[Bak_Config].[dbo].[Insert_into_Config] @type = 'L'
		End
	end
waitfor delay '00:00:10'
end
else iF @is_primary = @isPrimary and @is_critical = 0 and @is_primary = 1
begin
	IF (select count(*) from [Bak_Config].[dbo].[config] where backup_type = 'L' and status = 0) = 0
	Begin
		exec [Bak_Config].[dbo].[Insert_into_Config] @type = 'L'
	End
end
end
GO

CREATE PROCEDURE [dbo].[Transaction_Log_Backup_step2]
as
begin

declare @is_primary int, @is_critical int, @isPrimary bit
select @isPrimary = is_primary 
from Backup_Preferences

select @is_primary = case when name = (select Primary_replica from sys.dm_hadr_availability_group_states) then 1 else 0 end
from sys.servers
where server_id = 0

select @is_critical =
case 
when datepart(WEEKDAY, getdate()) = 7 and getdate() < dateadd(minute, 15, dateadd(hour, 23, convert(datetime,convert(date, getdate(),120),120)))
then 0
when datepart(WEEKDAY, getdate())  < 7 
then 0 
else 1 end

IF @is_primary = @isPrimary and @is_critical = 0
begin
	IF 
	(select count(*) from config where backup_type = 'L' and status = 0) = 1 and
	(select count(*) from sys.dm_exec_requests where command = 'Backup Log') = 0
	Begin
		exec [dbo].[backup_database_v03] @backup_type = 'L', @server_type = @isPrimary
	End
end
end
GO

CREATE PROCEDURE [dbo].[Transaction_Log_Backup_step3]
as
begin
declare @is_primary int, @is_critical int, @server_number int, @isPrimary bit
select @isPrimary = is_primary 
from Backup_Preferences

select 
@is_primary = case when name = (select Primary_replica from sys.dm_hadr_availability_group_states) then 1 else 0 end,
@server_number = left(reverse(substring(name,1,charindex('\', name)-1)),1)
from sys.servers
where server_id = 0

select @is_critical =
case 
when datepart(WEEKDAY, getdate()) = 7 and getdate() < dateadd(minute, 15, dateadd(hour, 23, convert(datetime,convert(date, getdate(),120),120)))
then 0
when datepart(WEEKDAY, getdate())  < 7 
then 0 
else 1 end

IF @is_primary = @isPrimary and @is_critical = 0 and @is_primary = 0
begin
	IF 
	(select count(*) from config where backup_type = 'L' and status = 0) = 1 and
	(select count(*) from sys.dm_exec_requests where command = 'Backup Log') = 0
	Begin
		if @server_number = 2
		begin
			update [AZ-WE-SQL001\AZ_SP_DB].[Bak_Config].[dbo].[config] set 
			backup_end = getdate(), 
			status = 1
			where status = 0
			and backup_type = 'L'
		end
		else if @server_number = 1
		begin
			update [AZ-WE-SQL002\AZ_SP_DB].[Bak_Config].[dbo].[config] set 
			backup_end = getdate(), 
			status = 1
			where status = 0
			and backup_type = 'L'
		end
	end
End
else if @is_primary = @isPrimary and @is_critical = 0 and @is_primary = 1
begin
	IF 
	(select count(*) from config where backup_type = 'L' and status = 0) = 1 and
	(select count(*) from sys.dm_exec_requests where command = 'Backup Log') = 0
	Begin
			update [Bak_Config].[dbo].[config] set 
		backup_end = getdate(), 
		status = 1
		where status = 0
		and backup_type = 'L'
	end
end
end
GO




