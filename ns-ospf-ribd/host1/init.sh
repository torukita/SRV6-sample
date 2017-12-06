#!/bin/bash

DIR=$(cd $(dirname $0); pwd)
router=`basename ${DIR}`

case "$1" in
    start)
        echo "Starting openconfigd on ${router}"
        openconfigd -c $DIR/coreswitch.conf &
        echo "Starting ribd on ${router}"        
        ribd &
        sleep 5
        mv /var/run/zserv.api /var/run/zserv-${router}.api
        ;;
    stop)
        pkill openconfigd
        pkill ribd
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        ;;
esac
exit 0



