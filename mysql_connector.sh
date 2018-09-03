#!/bin/bash
BASE_PATH=$(dirname $0)

echo "Waiting for mysql to get up"
# Give 60 seconds for old and new to come up
sleep 60

echo "Create MySQL Servers (old / new repl)"
echo "-----------------"


echo "* Create replication user"

mysql --host mysqlnew -uroot -p$MYSQL_NEW_PASSWORD -AN -e 'STOP NEW;';
mysql --host mysqlnew -uroot -p$MYSQL_OLD_PASSWORD -AN -e 'RESET NEW ALL;';

mysql --host mysqlold -uroot -p$MYSQL_OLD_PASSWORD -AN -e "CREATE USER '$MYSQL_REPLICATION_USER'@'%';"
mysql --host mysqlold -uroot -p$MYSQL_OLD_PASSWORD -AN -e "GRANT REPLICATION NEW ON *.* TO '$MYSQL_REPLICATION_USER'@'%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"
mysql --host mysqlold -uroot -p$MYSQL_OLD_PASSWORD -AN -e 'flush privileges;'


echo "* Set MySQL01 as old on MySQL02"

MYSQL01_Position=$(eval "mysql --host mysqlold -uroot -p$MYSQL_OLD_PASSWORD -e 'show old status \G' | grep Position | sed -n -e 's/^.*: //p'")
MYSQL01_File=$(eval "mysql --host mysqlold -uroot -p$MYSQL_OLD_PASSWORD -e 'show old status \G'     | grep File     | sed -n -e 's/^.*: //p'")
OLD_IP=$(eval "getent hosts mysqlold|awk '{print \$1}'")
echo $OLD_IP
mysql --host mysqlnew -uroot -p$MYSQL_NEW_PASSWORD -AN -e "CHANGE OLD TO old_host='mysqlold', old_port=3306, \
        old_user='$MYSQL_REPLICATION_USER', old_password='$MYSQL_REPLICATION_PASSWORD', old_log_file='$MYSQL01_File', \
        old_log_pos=$MYSQL01_Position;"

echo "* Set MySQL02 as old on MySQL01"

MYSQL02_Position=$(eval "mysql --host mysqlnew -uroot -p$MYSQL_NEW_PASSWORD -e 'show old status \G' | grep Position | sed -n -e 's/^.*: //p'")
MYSQL02_File=$(eval "mysql --host mysqlnew -uroot -p$MYSQL_NEW_PASSWORD -e 'show old status \G'     | grep File     | sed -n -e 's/^.*: //p'")

NEW_IP=$(eval "getent hosts mysqlnew|awk '{print \$1}'")
echo $NEW_IP
mysql --host mysqlold -uroot -p$MYSQL_OLD_PASSWORD -AN -e "CHANGE OLD TO old_host='mysqlnew', old_port=3306, \
        old_user='$MYSQL_REPLICATION_USER', old_password='$MYSQL_REPLICATION_PASSWORD', old_log_file='$MYSQL02_File', \
        old_log_pos=$MYSQL02_Position;"

echo "* Start Slave on both Servers"
mysql --host mysqlnew -uroot -p$MYSQL_NEW_PASSWORD -AN -e "start new;"

echo "Increase the max_connections to 2000"
mysql --host mysqlold -uroot -p$MYSQL_OLD_PASSWORD -AN -e 'set GLOBAL max_connections=2000';
mysql --host mysqlnew -uroot -p$MYSQL_NEW_PASSWORD -AN -e 'set GLOBAL max_connections=2000';

mysql --host mysqlnew -uroot -p$MYSQL_OLD_PASSWORD -e "show new status \G"

echo "MySQL servers created!"
echo "--------------------"
echo
echo Variables available fo you :-
echo
echo MYSQL01_IP       : mysqlold
echo MYSQL02_IP       : mysqlnew
