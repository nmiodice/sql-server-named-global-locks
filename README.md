# sql-server-named-global-locks

The SQL snippet in [locks.sql](locks.sql) define the following:
- `Lock` table, which managed global named locks
- `AcquireLock` stored procedure to take a lock
- `ReleaseLock` stored procedure to release a lock


## Usage

**Acquire Lock**

```sql
DECLARE @expires datetime2
EXECUTE dbo.AcquireLock
  'foo-lock',
  1000,
  @expires OUTPUT

SELECT @expires as 'expires'
```

Outputs `2021-01-14 18:42:18.2984012`

**Release Lock**

```sql
DECLARE @expires datetime2
EXECUTE dbo.AcquireLock
  'foo-lock',
  1000,
  @expires OUTPUT


DECLARE @released bit
EXECUTE dbo.ReleaseLock
  'foo-lock',
  @expires,
  @released OUTPUT

SELECT @released as 'released';
```

Outputs `true`

**Lock Expiration**

```sql
-- Take out a lock
DECLARE @expires datetime2
EXECUTE dbo.AcquireLock
  'foo-lock',
  1000,
  @expires OUTPUT

-- Allow first lock to expire
WAITFOR DELAY '00:00:02:00'

-- Take out a second lock
DECLARE @expiresSecond datetime2
EXECUTE dbo.AcquireLock
  'foo-lock',
  1000,
  @expiresSecond OUTPUT

-- Try to release first lock
DECLARE @released bit
EXECUTE dbo.ReleaseLock
  'foo-lock',
  @expires,
  @released OUTPUT

SELECT @released as 'first lock released?';
```

Outputs `false`
