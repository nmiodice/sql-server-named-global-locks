
-- This table represents named global locks used by the application
CREATE TABLE Lock (
	lock_id VARCHAR(100) PRIMARY KEY,
	expires datetime2 NOT NULL DEFAULT GETDATE()
);

-- This stored procedure will enable a consumer to acquire a global named lock subject to a timeout.
-- If the timeout expires, the lock may be taken by another process.
--
-- Parameters:
--  @lock_id       - The ID of the global lock
--  @timeoutMillis - The duration for which the lock will be held exclusively. After this, another
--                   process may acquire the lock.
--
-- Return:
--  @ret - The datetime2 when the lock expires
--
IF OBJECT_ID(N'dbo.AcquireLock', N'FN') IS NOT NULL 
    DROP FUNCTION dbo.AcquireLock ;
GO
CREATE PROCEDURE dbo.AcquireLock
    @lock_id VARCHAR(100),
    @timeoutMillis int,
    @ret datetime2 OUTPUT 
AS 
    BEGIN
    BEGIN TRANSACTION
        DECLARE @now DATETIME2
        DECLARE @expires DATETIME2
        
        SET NOCOUNT ON
        SET @now = SYSDATETIME()
        SET @expires = DATEADD(ms, @timeoutMillis, @now)

        -- If there is a lock that expires in the future, do not acquire the lock
		IF EXISTS (SELECT lock_id FROM Lock WHERE lock_id = @lock_id AND expires > @now)
          BEGIN
            SET @ret = '0001-01-01'
          END

        -- If there is a lock that that has already expired, acquire the lock
        ELSE IF EXISTS (SELECT lock_id FROM Lock WHERE lock_id = @lock_id)
          BEGIN
            SELECT @ret = @expires
            UPDATE Lock SET expires = @expires WHERE lock_id = @lock_id
          END
        
        -- If no lock exists, create it for the first time
        ELSE
          BEGIN
            SELECT @ret = @expires
            INSERT INTO Lock (lock_id, expires) VALUES (@lock_id, @expires)
          END
    COMMIT
    END


-- This stored procedure will enable a consumer to release a global named lock
--
-- Parameters:
--  @lock_id - The ID of the global lock
--  @expires - The date at which the lock expires
--
-- Return:
--  @ret - 0 if the lock expired or does not exist, 1 if the lock was successfully released
--
IF OBJECT_ID(N'dbo.ReleaseLock', N'FN') IS NOT NULL 
    DROP FUNCTION dbo.ReleaseLock ;
GO
CREATE PROCEDURE dbo.ReleaseLock
    @lock_id VARCHAR(100),
    @expires DATETIME2,
    @ret BIT OUTPUT 
AS 
    BEGIN
    BEGIN TRANSACTION
        SET NOCOUNT ON

        -- If another process acquired the lock, then it cannot be released
		IF NOT EXISTS (SELECT lock_id FROM Lock WHERE lock_id = @lock_id AND expires = @expires)
          BEGIN
            SET @ret = 0
          END
        ELSE
          BEGIN
            DELETE FROM Lock WHERE lock_id = @lock_id
            SET @ret = 1
          END
    COMMIT
    END
-- End ReleaseLock