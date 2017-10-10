#!/bin/bash
backup_dir="/var/lib/backups/mysql"
filename="${backup_dir}/mysql-`hostname`-`eval date +%Y%m%d`.sql.gz"
DBUSER='root' # Assuming there is a correct password for DBUSER in ~/.my.cnf
DBNAME='nova'
DBHOST='localhost'
DBPASS='DB_PASS'

# Dump the entire MySQL database
/usr/bin/mysqldump -u${DBUSER} -p${DBPASS} --opt --all-databases | gzip > $filename
# Delete backups older than 7 days
find $backup_dir -ctime +7 -type f -delete
