#!/bin/bash

VHOME="/home/tohru/SRV6-sample/ns-ospf/host3"

case "$1" in
    start)
        /sbin/ip route flush proto zebra
        /bin/chmod -f 666 $VHOME/vtysh.conf $VHOME/zebra.conf
        echo "Starting zebra on host3"
        /usr/sbin/zebra -d -A 127.0.0.1 -f $VHOME/zebra.conf -i $VHOME/run/zebra.pid -z $VHOME/run/zserv.api
        
        echo "Starting ospf6d on host3"
        /usr/sbin/ospf6d -d -A ::1 -f $VHOME/ospf6d.conf -i $VHOME/run/ospf6d.pid -z $VHOME/run/zserv.api
        ;;
    stop)
        pkill -F $VHOME/run/zebra.pid
        pkill -F $VHOME/run/ospf6d.pid
        rm -rf $VHOME/run/zserv.api
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        ;;
esac
exit 0



