#!/usr/bin/env bash
set -o pipefail

DBUSER='root' # Assuming there is a correct password for DBUSER in ~/.my.cnf
DBNAME='nova'
DBHOST='localhost'
DBPASS='DB_PASS'

# Set number of instances, ram, core usage to 0 for all users in all tenants, otherwise end result may not be correct:

mysql -u${DBUSER} -p${DBPASS}  -h ${DBHOST} -e "use ${DBNAME}; update quota_usages, (select user_id, project_id from instances group by user_id, project_id) as r set in_use='0' where quota_usages.user_id=r.user_id and quota_usages.project_id=r.project_id and resource='instances';"
mysql -u${DBUSER} -p${DBPASS}  -h ${DBHOST} -e "use ${DBNAME}; update quota_usages, (select user_id, project_id from instances group by user_id, project_id) as r set in_use='0' where quota_usages.user_id=r.user_id and quota_usages.project_id=r.project_id and resource='ram';"
mysql -u${DBUSER} -p${DBPASS}  -h ${DBHOST} -e "use ${DBNAME}; update quota_usages, (select user_id, project_id from instances group by user_id, project_id) as r set in_use='0' where quota_usages.user_id=r.user_id and quota_usages.project_id=r.project_id and resource='cores';"

# Calculate number of instances for each of users in each tenant and update data in quota_usages table:

mysql -u${DBUSER} -p${DBPASS}  -h ${DBHOST} -e "use ${DBNAME}; update quota_usages, (select user_id, project_id, COUNT(*) as sum from instances where project_id in (select project_id from quota_usages group by project_id) and deleted!=id group by user_id, project_id) as r set quota_usages.in_use = r.sum where quota_usages.user_id = r.user_id and quota_usages.project_id = r.project_id and resource='instances';"

mysql -u${DBUSER} -p${DBPASS}  -h ${DBHOST} -e "use ${DBNAME}; update quota_usages, (select user_id, project_id, SUM(memory_mb) as sum from instances where project_id in (select project_id from quota_usages group by project_id) and deleted!=id group by user_id, project_id) as r set quota_usages.in_use = r.sum where quota_usages.user_id = r.user_id and quota_usages.project_id = r.project_id and resource='ram';"

mysql -u${DBUSER} -p${DBPASS}  -h ${DBHOST} -e "use ${DBNAME}; update quota_usages, (select user_id, project_id, SUM(vcpus) as sum from instances where project_id in (select project_id from quota_usages group by project_id) and deleted!=id group by user_id, project_id) as r set quota_usages.in_use = r.sum where quota_usages.user_id = r.user_id and quota_usages.project_id = r.project_id and resource='cores';"
