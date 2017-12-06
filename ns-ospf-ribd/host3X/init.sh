#!/bin/bash

DIR=$(cd $(dirname $0); pwd)
router=`basename ${DIR}`

case "$1" in
    start)
        /sbin/ip route flush proto zebra
        /bin/chmod -f 666 $DIR/vtysh.conf $DIR/zebra.conf
        mkdir -p run
        chmod a+w run
        echo "Starting zebra on $router"
        /usr/sbin/zebra -d -A 127.0.0.1 -f $DIR/zebra.conf -i $DIR/run/zebra.pid -z $DIR/run/zserv.api
        
        /bin/chmod -f 666 $DIR/ospf6d.conf
        echo "Starting ospf6d on $router"
        /usr/sbin/ospf6d -d -A ::1 -f $DIR/ospf6d.conf -i $DIR/run/ospf6d.pid -z $DIR/run/zserv.api
        ;;
    stop)
        pkill -F $DIR/run/zebra.pid
        pkill -F $DIR/run/ospf6d.pid
        rm -rf $DIR/run/zebra.pid
        rm -rf $DIR/run/ospf6d.pid
        rm -rf $DIR/run/zserv.api
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        ;;
esac
exit 0



