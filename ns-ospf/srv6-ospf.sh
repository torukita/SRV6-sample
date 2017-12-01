#! /bin/bash
#

NTOPOLOGY=$(cat <<EOF
#========================================================================================
#  Network Topology
#
#                                +--------------+          +-------------+
#                                |   routerA    |          |   routerC   |
#              host1 veth1 -- vethA1        vethAC  --  vethCA       vethC3 -- veth3C host3X - veth3
#                                |              |          |             |
#                                +--- vethAD ---+          +--- vethCB --+
#                                       |                         |
#                                       |                         |
#                                +--- vethDA ---+          +--- vethBC --+
#                                |              |          |             |
# (veth3 - host3Y - veth3D) -- vethD3      vethDB  --  vethBD        vethB2 -- veth2 host2
#                                |   routerD    |          |    routerB  |
#                                +--------------+          +-------------+
#
#      (PLAN: stop host3X and start host3Y. fc00:3::10 address is same)
#
# Hosts:
#     host1:
#        veth1: fc00:000a::10/64
#        default gw: fc00:000a::a
#     host2:
#        veth2: fc00:000b::10/64
#        default gw: fc00:000b::b
# Routers:
#     routerA:
#        vethA1: fc00:000a::a/64
#        vethAC: fc00:00ac::a/64
#        vethAD: fc00:00ad::a/64
#     routerB:
#        vethBC: fc00:00bc::b/64
#        vethBD: fc00:00bd::b/64
#        vethB2: fc00:000b::b/64
#     routerC:
#        vethCA: fc00:00ac::c/64
#        vethCB: fc00:00bc::c/64
#        vethC3: fc00:00c3::c/64 (Send RA)
#     routerD:
#        vethDA: fc00:00ad::d/64
#        vethDB: fc00:00bd::d/64
#        vethD3: fc00:00d3::d/64 (Send RA)
# Hosts and Routers:
#    host3X:
#        veth3C: accept RA from routerC
#        veth3 : fc00:0003::10/64 (dummy interface)
#   After stop host3X and start host3Y 
#   (host3Y:
#        veth3D: accept RA from routerD
#        veth3 : fc00:0003::10/64 (dummy interface)
#   )
#
# Desc:
#     AC - fc00:00ac::/64
#     AD - fc00:00ad::/64
#     BC - fc00:00bc::/64
#     BD - fc00:00bd::/64
#
#     vethA1 encaps dest address(fc00:000b::10) as seg6 via fc00:0003::10
#     vethB2 encaps dest address(fc00:000a::10) as seg6 via fc00:0003::10
#
#     fc00:000a::10 <---> fc00:000b:10 communicates via host3[XY] (fc00:0003::10)
#
# Example:
#     TODO: stop 3X or 3Y script
#     ip netns exec host1 ping fc00:000b::10
#     ip netns exec host3X tcpdump -n -e -l -i veth3C
#                   or
#     ip netns exec host3Y tcpdump -n -e -l -i veth3D
#
#     you might want to make sure with netcat ...
#         
#=======================================================
** Exit to this shell to kill ** 
EOF
)

VERSION="0.0.6"

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
    run ip netns add host3X
    run ip netns add host3Y
    
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
    run ip link set veth3C netns host3X
    run ip link set vethC3 netns routerC

    run ip link add name veth3D type veth peer name vethD3
    run ip link set veth3D netns host3Y
    run ip link set vethD3 netns routerD
    
    # host1 configuration
    run ip netns exec host1 ip link set lo up
    run ip netns exec host1 ip ad add fc00:000a::10/64 dev veth1
    run ip netns exec host1 ip link set veth1 up        
    run ip netns exec host1 ip -6 route add default via fc00:000a::a
    
    # routerA configuration
    run ip netns exec routerA ip link set lo up
    ip netns exec routerA sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec routerA sysctl net.ipv6.conf.all.seg6_enabled=1
    ip netns exec routerA sysctl net.ipv6.conf.vethAC.seg6_enabled=1
    ip netns exec routerA sysctl net.ipv6.conf.vethAD.seg6_enabled=1    
    ip netns exec routerA ./routerA/init.sh start    
    run ip netns exec routerA ip -6 route add fc00:000b::10/128 encap seg6 mode encap segs fc00:3::10 dev vethA1

    # routerC configuration
    run ip netns exec routerC ip link set lo up
    ip netns exec routerC sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec routerC sysctl net.ipv6.conf.all.seg6_enabled=1
    ip netns exec routerC sysctl net.ipv6.conf.vethCA.seg6_enabled=1
    ip netns exec routerC sysctl net.ipv6.conf.vethCB.seg6_enabled=1
    ip netns exec routerC sysctl net.ipv6.conf.vethC3.seg6_enabled=1
    ip netns exec routerC ./routerC/init.sh start

    # routerD configuration
    run ip netns exec routerD ip link set lo up
    ip netns exec routerD sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec routerD sysctl net.ipv6.conf.all.seg6_enabled=1
    ip netns exec routerD sysctl net.ipv6.conf.vethDA.seg6_enabled=1
    ip netns exec routerD sysctl net.ipv6.conf.vethDB.seg6_enabled=1
    ip netns exec routerD sysctl net.ipv6.conf.vethD3.seg6_enabled=1    
    ip netns exec routerD ./routerD/init.sh start    
    
    # routerB configuration
    run ip netns exec routerB ip link set lo up
    ip netns exec routerB sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec routerB sysctl net.ipv6.conf.all.seg6_enabled=1
    ip netns exec routerB sysctl net.ipv6.conf.vethBC.seg6_enabled=1
    ip netns exec routerB sysctl net.ipv6.conf.vethBD.seg6_enabled=1    
    ip netns exec routerB ./routerB/init.sh start

    run ip netns exec routerB ip -6 route add fc00:000a::10/128 encap seg6 mode encap segs fc00:3::10 dev vethB2    

    # host3X configuration
    run ip netns exec host3X ip link set lo up
    run ip netns exec host3X ip link add veth3 type dummy
    run ip netns exec host3X ip link set veth3 up
    run ip netns exec host3X ip link set veth3C up
    ip netns exec host3X sysctl net.ipv6.conf.veth3C.accept_ra=2
    ip netns exec host3X sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec host3X sysctl net.ipv6.conf.all.seg6_enabled=1
    ip netns exec host3X sysctl net.ipv6.conf.veth3C.seg6_enabled=1
    ip netns exec host3X sysctl net.ipv6.conf.veth3.seg6_enabled=1    
    ip netns exec host3X ./host3X/init.sh start

    # host3Y configuration
    run ip netns exec host3Y ip link set lo up
    run ip netns exec host3Y ip link add veth3 type dummy
    run ip netns exec host3Y ip link set veth3 down
    run ip netns exec host3Y ip link set veth3D down
    ip netns exec host3Y sysctl net.ipv6.conf.veth3D.accept_ra=2
    ip netns exec host3Y sysctl net.ipv6.conf.all.forwarding=1
    ip netns exec host3Y sysctl net.ipv6.conf.all.seg6_enabled=1
    ip netns exec host3Y sysctl net.ipv6.conf.veth3D.seg6_enabled=1
    ip netns exec host3Y sysctl net.ipv6.conf.veth3.seg6_enabled=1    
    ip netns exec host3Y ./host3Y/init.sh start

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
    run ip netns exec host3X ./host3X/init.sh stop
    run ip netns del host3X
    run ip netns exec host3Y ./host3Y/init.sh stop    
    run ip netns del host3Y

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
