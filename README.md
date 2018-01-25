# LinuxBackup
Backup the database and logs on Linux. Only tested on a VPS running Ubuntu

<b>Example Usage:</b>

- `./file_backup.sh /path/to/file --split-size=15m --email=me@email.com` (email file split into 15mb parts)

- `./file_backup.sh /var/log/error.log --disable-compression --email=me@email.com` (email log as text file)

- `./database_backup.sh /credentials.conf --email=me@email.com` (generate sql dump - planned)
- `./log_backup.sh /var/log --rotation-only --delete --email=me@email.com` (only email rotated logs like `error.log.1` - planned)

<b>How it works:</b>

The file will be copied into a temporary folder, where it may or may not be compressed and split depending on the options. Currently only email is supported, but other technologies such as Amazon S3 or Dropbox could easily be implemented.

<b>Requirements:</b>

- mutt (for email)
