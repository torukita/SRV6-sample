#! /bin/bash
#

NTOPOLOGY=$(cat <<EOF
#========================================================================================
#  Network Topology
#
#                   +--------------+
#                   |   routerA    |
#  host1 veth1 -- vethA            |  vethA adds SRH routerB for fc00:000b::/64
#                   |   vethA-C    |  routerA knows the route of routerB
#                   +------+-------+
#                          |
#                   +------+-------+ 
#                   |   vethC-A    |  
#                   |   routerC    |   
#                   |   vethC-B    |
#                   +------+-------+
#                          |
#                   +------+-------+  
#                   |  vethB-C     | 
#                   |            vethB -- veth2 host2
#                   |   routerB    | vethB adds SRH routerA for fc00:000a::/64
#                   +--------------+ routerB knows the route of routerA
#
# Hosts:
#     host1:
#        veth1: fc00:000a::10/64
#     host2:
#        veth2: fc00:000b::10/64
# Routers:
#     routerA:
#        vethA:   fc00:000a::1/64
#        vethA-C: fc00:00ac::1/64
#     routerC:
#        vethC-A: fc00:00ac::2/64
#        vethC-B: fc00:00bc::2/64   
#     routerB:
#        vethB-C: fc00:00bc::1/64
#        vethB:   fc00:000b::1/64
#
# Example:
#     ip netns exec host1 ping fc00:000b::10
#     ip netns exec host2 ping fc00:000a::10
#=======================================================
** Exit to this shell to kill ** 
EOF
)

VERSION="0.0.2"

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
    run ip netns add routerA
    run ip netns add routerC    
    run ip netns add routerB
    run ip netns add host2

    run ip link add name veth1 type veth peer name vethA
    run ip link set veth1 netns host1
    run ip link set vethA netns routerA

    run ip link add name vethA-C type veth peer name vethC-A
    run ip link set vethA-C netns routerA
    run ip link set vethC-A netns routerC

    run ip link add name vethC-B type veth peer name vethB-C
    run ip link set vethC-B netns routerC
    run ip link set vethB-C netns routerB

    run ip link add name veth2 type veth peer name vethB
    run ip link set veth2 netns host2
    run ip link set vethB netns routerB

    # host1 configuration
    run ip netns exec host1 ip link set lo up
    run ip netns exec host1 ip ad add fc00:000a::10/64 dev veth1
    run ip netns exec host1 ip link set veth1 up
    run ip netns exec host1 ip -6 route add fc00:000b::/64 via fc00:000a::1
    
    # routerA configuration
    run ip netns exec routerA ip link set lo up
    ip netns exec routerA sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec routerA sysctl net.ipv6.conf.all.seg6_enabled=1
    run ip netns exec routerA ip ad add fc00:000a::1/64 dev vethA
    run ip netns exec routerA ip link set vethA up
    ip netns exec routerA sysctl net.ipv6.conf.vethA.seg6_enabled=1
    run ip netns exec routerA ip ad add fc00:00ac::1/64 dev vethA-C
    run ip netns exec routerA ip link set  vethA-C up
    ip netns exec routerA sysctl net.ipv6.conf.vethA-C.seg6_enabled=1
    run ip netns exec routerA ip -6 route add fc00:00bc::/64 via fc00:00ac::2
    run ip netns exec routerA ip -6 route add fc00:000b::/64 encap seg6 mode encap segs fc00:00bc::1 dev vethA

    # routerC configuration
    run ip netns exec routerC ip link set lo up
    ip netns exec routerC sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec routerC sysctl net.ipv6.conf.all.seg6_enabled=1
    run ip netns exec routerC ip ad add fc00:00ac::2/64 dev vethC-A
    run ip netns exec routerC ip link set vethC-A up
    ip netns exec routerC sysctl net.ipv6.conf.vethC-A.seg6_enabled=1
    run ip netns exec routerC ip ad add fc00:00bc::2/64 dev vethC-B
    run ip netns exec routerC ip link set vethC-B up
    ip netns exec routerC sysctl net.ipv6.conf.vethC-B.seg6_enabled=1
    
    # routerB configuration
    run ip netns exec routerB ip link set lo up
    ip netns exec routerB sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec routerB sysctl net.ipv6.conf.all.seg6_enabled=1
    run ip netns exec routerB ip ad add fc00:000b::1/64 dev vethB
    run ip netns exec routerB ip link set vethB up
    ip netns exec routerB sysctl net.ipv6.conf.vethB.seg6_enabled=1
    run ip netns exec routerB ip ad add fc00:00bc::1/64 dev vethB-C
    run ip netns exec routerB ip link set vethB-C up
    
    ip netns exec routerB sysctl net.ipv6.conf.vethB-C.seg6_enabled=1
    run ip netns exec routerB ip -6 route add fc00:00ac::/64 via fc00:00bc::2
    run ip netns exec routerB ip -6 route add fc00:000a::/64 encap seg6 mode encap segs fc00:00ac::1 dev vethB
    
    # host2 configuration
    run ip netns exec host2 ip link set lo up
    run ip netns exec host2 ip ad add fc00:000b::10/64 dev veth2
    run ip netns exec host2 ip link set veth2 up
    run ip netns exec host2 ip -6 route add fc00:000a::/64 via fc00:000b::1
}

destroy_network () {
    run ip netns  del host1
    run ip netns  del routerA
    run ip netns  del routerC    
    run ip netns  del routerB
    run ip netns  del host2    
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
