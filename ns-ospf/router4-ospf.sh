#! /bin/bash
#

NTOPOLOGY=$(cat <<EOF
#========================================================================================
#  Network Topology
#
#                   +--------------+          +-------------+
#                   |   routerA    |          |   routerB   |
#  host1 veth1 -- vethA        vethA-B  --  vethB-A       vethB -- veth2 host2
#                   |              |          |             |
#                   +--------------+          +-------------+
#
#
# Hosts:
#     host1:
#        veth1: fc00:000a::10/64
#     host2:
#        veth2: fc00:000b::10/64
# Routers:
#     routerA:
#        vethA:   fc00:000a::1/64
#        vethA-B: fc00:00ab::1/64
#     routerB:
#        vethB-A: fc00:00ab::2/64
#        vethB:   fc00:000b::1/64
#
# Example:
#     ip netns exec host1 ping fc00:000b::10
#     ip netns exec host2 ping fc00:000a::10
#     AC - fc00:00ac::/64
#     AD - fc00:00ad::/64
#     BC - fc00:00bc::/64
#     BD - fc00:00bd::/64
#=======================================================
** Exit to this shell to kill ** 
EOF
)

VERSION="0.0.4"

if [[ $(id -u) -ne 0 ]] ; then echo "Please run with sudo" ; exit 1 ; fi

set -e

run () {
    echo "$@"
    "$@" || exit 1
}

silent () {
    "$@" 2> /dev/null || true
}

create_network () {
    run ip netns add host1
    run ip netns add host2
    run ip netns add host3
    run ip netns add routerA
    run ip netns add routerB
    run ip netns add routerC
    run ip netns add routerD

    run ip link add name veth1 type veth peer name vethA1
    run ip link set veth1 netns host1

    run ip link add name veth2 type veth peer name vethB2
    run ip link set veth2 netns host2
    
    run ip link add name vethAC type veth peer name vethCA
    run ip link set vethA1 netns routerA    
    run ip link set vethAC netns routerA
    run ip link set vethCA netns routerC


    run ip link add name vethAD type veth peer name vethDA
    run ip link set vethAD netns routerA
    run ip link set vethDA netns routerD

    run ip link add name vethBC type veth peer name vethCB
    run ip link set vethBC netns routerB
    run ip link set vethCB netns routerC

    run ip link add name vethBD type veth peer name vethDB
    run ip link set vethB2 netns routerB
    run ip link set vethBD netns routerB
    run ip link set vethDB netns routerD

    run ip link add name veth3C type veth peer name vethC3
    run ip link set veth3C netns host3
    run ip link set vethC3 netns routerC

    # host1 configuration
    run ip netns exec host1 ip link set lo up
    run ip netns exec host1 ip ad add fc00:000a::10/64 dev veth1
    run ip netns exec host1 ip link set veth1 up        
    run ip netns exec host1 ip -6 route add default via fc00:000a::a
    
    # routerA configuration
    run ip netns exec routerA ip link set lo up
    ip netns exec routerA sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec routerA sysctl net.ipv6.conf.all.seg6_enabled=1
    ip netns exec routerA ./routerA/init.sh start        
#    run ip netns exec routerA ip ad add fc00:00ac::a/64 dev vethAC
#    run ip netns exec routerA ip link set vethAC up
#    run ip netns exec routerA ip ad add fc00:00ad::a/64 dev vethAD
#    run ip netns exec routerA ip link set vethAD up

    # routerB configuration
    run ip netns exec routerB ip link set lo up
    ip netns exec routerB sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec routerB sysctl net.ipv6.conf.all.seg6_enabled=1
    ip netns exec routerB ./routerB/init.sh start    
#    run ip netns exec routerB ip ad add fc00:00bc::b/64 dev vethBC
#    run ip netns exec routerB ip link set vethBC up
#    run ip netns exec routerB ip ad add fc00:00bd::b/64 dev vethBD
#    run ip netns exec routerB ip link set vethBD up

    # routerC configuration
    run ip netns exec routerC ip link set lo up
    ip netns exec routerC sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec routerC sysctl net.ipv6.conf.all.seg6_enabled=1
    ip netns exec routerC ./routerC/init.sh start
#    run ip netns exec routerC ip ad add fc00:00ac::c/64 dev vethCA
#    run ip netns exec routerC ip link set vethCA up
#    run ip netns exec routerC ip ad add fc00:00bc::c/64 dev vethCB
 #   run ip netns exec routerC ip link set vethCB up

        # routerD configuration
    run ip netns exec routerD ip link set lo up
    ip netns exec routerD sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec routerD sysctl net.ipv6.conf.all.seg6_enabled=1
    ip netns exec routerD ./routerD/init.sh start    
#    run ip netns exec routerD ip ad add fc00:00ad::d/64 dev vethDA
#    run ip netns exec routerD ip link set vethDA up
#    run ip netns exec routerD ip ad add fc00:00bd::d/64 dev vethDB
#    run ip netns exec routerD ip link set vethDB up

    # host3 configuration

    run ip netns exec host3 ip link set lo up
    run ip netns exec host3 ip link add veth3 type dummy
    run ip netns exec host3 ip link set veth3 up
    ip netns exec host3 sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec host3 sysctl net.ipv6.conf.all.seg6_enabled=1
    ip netns exec host3 ./host3/init.sh start

#    run ip netns exec host3 ip ad add fc00:00c3::10/64 dev veth3
#    run ip netns exec host3 ip link set veth3 up
#    run ip netns exec host3 ip -6 route add default via fc00:00c3::c
    
#    ip netns exec routerA sysctl net.ipv6.conf.vethAC.seg6_enabled=1
#    run ip netns exec routerA ip ad add fc00:00ab::1/64 dev vethA-B
#    run ip netns exec routerA ip link set vethA-B up
#    ip netns exec routerA sysctl net.ipv6.conf.vethA-B.seg6_enabled=1
#    run ip netns exec routerA ip -6 route add fc00:000b::/64 encap seg6 mode encap segs fc00:00ab::2 dev vethA

    # routerB configuration
#    run ip netns exec routerB ip link set lo up
#    ip netns exec routerB sysctl net.ipv6.conf.all.forwarding=1
#    ip netns exec routerB sysctl net.ipv6.conf.all.seg6_enabled=1
#    run ip netns exec routerB ip ad add fc00:000b::1/64 dev vethB
#    run ip netns exec routerB ip link set vethB up
#    ip netns exec routerB sysctl net.ipv6.conf.vethB.seg6_enabled=1
#    run ip netns exec routerB ip ad add fc00:00ab::2/64 dev vethB-A
#    run ip netns exec routerB ip link set vethB-A up
#    ip netns exec routerB sysctl net.ipv6.conf.vethB-A.seg6_enabled=1
#    run ip netns exec routerB ip -6 route add fc00:000a::/64 encap seg6 mode encap segs fc00:00ab::1 dev vethB
    
    # host2 configuration
    run ip netns exec host2 ip link set lo up
    run ip netns exec host2 ip ad add fc00:000b::10/64 dev veth2
    run ip netns exec host2 ip link set veth2 up        
    run ip netns exec host2 ip -6 route add default via fc00:b::b
}

destroy_network () {
    run ip netns exec routerA ./routerA/init.sh stop        
    run ip netns del routerA
    run ip netns exec routerB ./routerB/init.sh stop    
    run ip netns del routerB
    run ip netns exec routerC ./routerC/init.sh stop
    run ip netns del routerC
    run ip netns exec routerD ./routerD/init.sh stop    
    run ip netns del routerD
    run ip netns exec host3 ./host3/init.sh stop
    run ip netns del host3

    run ip netns del host1
    run ip netns del host2
}

stop () {
    destroy_network
}

trap stop 0 1 2 3 13 14 15

create_network

echo "$NTOPOLOGY"

PROMPT_COMMAND="echo -n [SRv6\($VERSION\)]";export PROMPT_COMMAND
status=0; $SHELL || status=$?

cat <<EOF
-----
Cleaned Virtual Network Topology successfully
-----
EOF

exit $status
