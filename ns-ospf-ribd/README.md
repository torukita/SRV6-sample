# SRV6 + OSPFv3 + zebra2

# 環境

 - ubuntu 17.10
 - iproute2 リプレイス
 - quagga
 - openconfigd
 - ribd
 
# 準備

```
sudo apt install build-essential
sudo apt install pkg-config
sudo apt install bison
sudo apt install flex
sudo apt install quagga

git clone https://github.com/segment-routing/iproute2.git
cd iproute2
./configure
make
sudo make install

go get -v github.com/coreswitch/openconfigd/openconfigd
go get -v github.com/coreswitch/openconfigd/cli_command
cd $GOPATH/src/github.com/coreswitch/openconfigd/cli
make
sudo make install
cd $GOPATH/src/github.com/coreswitch/openconfigd/bash_completion.d
sudo cp cli /etc/bash_completion.d/

go get -v github.com/coreswitch/zebra/rib/ribd
```

```
cd $HOME
git clone github.com/torukita/SRV6-sample.git
cd SRV6-sample
cd ns-ospf-ribd
```

# 手順 1.

```
sudo GOPATH=/home/ubuntu/go ./start.sh
```

routerAに経路が届くまで待つ。
しばらく時間がかかる。適当に他のhostで確認するもよし。  

```
[SRv6(0.0.2)]root@srv6-demo:~/SRV6-sample/ns-ospf-ribd# ip netns exec routerA ip -6 route show
fc00:3::/64 via fe80::7800:95ff:fe95:ca60 dev vethAC proto zebra metric 20 pref medium
fc00:a::/64 dev vethA1 proto kernel metric 256 pref medium
fc00:b::/64 proto zebra metric 20
	nexthop via fe80::6c39:f9ff:fe65:ec83 dev vethAD weight 1
	nexthop via fe80::7800:95ff:fe95:ca60 dev vethAC weight 1
fc00:ac::/64 dev vethAC proto kernel metric 256 pref medium
fc00:ad::/64 dev vethAD proto kernel metric 256 pref medium
fc00:bc::/64 via fe80::7800:95ff:fe95:ca60 dev vethAC proto zebra metric 20 pref medium
fc00:bd::/64 via fe80::6c39:f9ff:fe65:ec83 dev vethAD proto zebra metric 20 pref medium
fc00:c3::/64 via fe80::7800:95ff:fe95:ca60 dev vethAC proto zebra metric 20 pref medium
fe80::/64 dev vethA1 proto kernel metric 256 pref medium
fe80::/64 dev vethAC proto kernel metric 256 pref medium
fe80::/64 dev vethAD proto kernel metric 256 pref medium
```

最終的に、上記のような経路。  
fc00:3::/64とfc00:b::/64の経路が表示されている。

```
[SRv6(0.0.2)]root@srv6-demo:~/SRV6-sample/ns-ospf-ribd# ip netns exec host1 ping fc00:b::10
PING fc00:b::10(fc00:b::10) 56 data bytes
64 bytes from fc00:b::10: icmp_seq=1 ttl=61 time=0.312 ms
64 bytes from fc00:b::10: icmp_seq=2 ttl=61 time=0.087 ms
^C
```
pingが届く。  

## 手順 2.

host3をrouterCからrouterDへ移動する想定。  

これは、便宜上、host3XとrouterCの接続であるveth3Cをリンクダウンする。  
そして、routerDについているhost3Yのveth3Dをリンクアップする。  
host3Xおよびhost3Yにはveth3のdummy interfaceを作り、fc00:3::10というアドレスを割り当てている。

```
ip netns exec host3X ip link set veth3C down
```

routerAで経路が消える。(host3がダウンした想定になる)  
```
[SRv6(0.0.2)]root@srv6-demo:~/SRV6-sample/ns-ospf-ribd# ip netns exec routerA ip -6 route show
fc00:a::/64 dev vethA1 proto kernel metric 256 pref medium
fc00:b::/64 proto zebra metric 20
	nexthop via fe80::4c2f:5dff:fe2e:1844 dev vethAC weight 1
	nexthop via fe80::90ae:8eff:feea:713c dev vethAD weight 1
fc00:ac::/64 dev vethAC proto kernel metric 256 pref medium
fc00:ad::/64 dev vethAD proto kernel metric 256 pref medium
fc00:bc::/64 via fe80::4c2f:5dff:fe2e:1844 dev vethAC proto zebra metric 20 pref medium
fc00:bd::/64 via fe80::90ae:8eff:feea:713c dev vethAD proto zebra metric 20 pref medium
fe80::/64 dev vethA1 proto kernel metric 256 pref medium
fe80::/64 dev vethAC proto kernel metric 256 pref medium
fe80::/64 dev vethAD proto kernel metric 256 pref medium
```

```
ip netns exec host3Y ip link set veth3D up
```

host3をrouterDへ接続した想定。。
しばらくすると、routerA上に経路がながれてくる。。

```
[SRv6(0.0.2)]root@srv6-demo:~/SRV6-sample/ns-ospf-ribd# ip netns exec routerA ip -6 route show
fc00:3::/64 via fe80::24af:feff:fec5:399d dev vethAD proto zebra metric 20 pref medium
fc00:a::/64 dev vethA1 proto kernel metric 256 pref medium
fc00:b::/64 proto zebra metric 20
	nexthop via fe80::f055:53ff:fedb:55f7 dev vethAC weight 1
	nexthop via fe80::24af:feff:fec5:399d dev vethAD weight 1
fc00:ac::/64 dev vethAC proto kernel metric 256 pref medium
fc00:ad::/64 dev vethAD proto kernel metric 256 pref medium
fc00:bc::/64 via fe80::f055:53ff:fedb:55f7 dev vethAC proto zebra metric 20 pref medium
fc00:bd::/64 via fe80::24af:feff:fec5:399d dev vethAD proto zebra metric 20 pref medium
fc00:d3::/64 via fe80::24af:feff:fec5:399d dev vethAD proto zebra metric 20 pref medium
fe80::/64 dev vethA1 proto kernel metric 256 pref medium
fe80::/64 dev vethAC proto kernel metric 256 pref medium
fe80::/64 dev vethAD proto kernel metric 256 pref medium
```

さきほどと違い、fc00:3::/64はrouter Dを経由することがわかる。host3がrouterDへ移動した想定になる。  

pingして、host2へ通信できるようになる。  

```
[SRv6(0.0.2)]root@srv6-demo:~/SRV6-sample/ns-ospf-ribd# ip netns exec host1 ping fc00:b::10
PING fc00:b::10(fc00:b::10) 56 data bytes
64 bytes from fc00:b::10: icmp_seq=1 ttl=61 time=0.291 ms
64 bytes from fc00:b::10: icmp_seq=2 ttl=61 time=0.092 ms
64 bytes from fc00:b::10: icmp_seq=3 ttl=61 time=0.090 ms
^C
```

## お片づけ

Terminal Aにて、

```
exit
sudo ip netns
```

exitすれば、綺麗にお片づけしてくれる。（問題なければ)。  
念のためnetnsが消えているか確認。  


## 補足

### 複数ターミナルを使用する場合

```
sudo -s
export GOPATH=/home/ubuntu/go
export PATH=$GOPATH/bin:$PATH
```

### host3上でのキャプチャ

```
ip netns exec host3X tcpdump -n -e -l -i veth3C
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on veth3C, link-type EN10MB (Ethernet), capture size 262144 bytes
12:49:05.180092 e6:a1:18:75:81:f8 > ea:39:ee:f6:8f:f3, ethertype IPv6 (0x86dd), length 182: fc00:a::a > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:49:05.180118 e6:a1:18:75:81:f8 > ea:39:ee:f6:8f:f3, ethertype IPv6 (0x86dd), length 182: fc00:a::a > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:49:05.180131 ea:39:ee:f6:8f:f3 > e6:a1:18:75:81:f8, ethertype IPv6 (0x86dd), length 118: fc00:a::10 > fc00:b::10: ICMP6, echo request, seq 16, length 64
12:49:05.180186 e6:a1:18:75:81:f8 > ea:39:ee:f6:8f:f3, ethertype IPv6 (0x86dd), length 182: fc00:b::b > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:49:05.180190 e6:a1:18:75:81:f8 > ea:39:ee:f6:8f:f3, ethertype IPv6 (0x86dd), length 182: fc00:b::b > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:49:05.180196 ea:39:ee:f6:8f:f3 > e6:a1:18:75:81:f8, ethertype IPv6 (0x86dd), length 118: fc00:b::10 > fc00:a::10: ICMP6, echo reply, seq 16, length 64
12:49:06.204082 e6:a1:18:75:81:f8 > ea:39:ee:f6:8f:f3, ethertype IPv6 (0x86dd), length 182: fc00:a::a > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:49:06.204111 e6:a1:18:75:81:f8 > ea:39:ee:f6:8f:f3, ethertype IPv6 (0x86dd), length 182: fc00:a::a > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:49:06.204125 ea:39:ee:f6:8f:f3 > e6:a1:18:75:81:f8, ethertype IPv6 (0x86dd), length 118: fc00:a::10 > fc00:b::10: ICMP6, echo request, seq 17, length 64
12:49:06.204188 e6:a1:18:75:81:f8 > ea:39:ee:f6:8f:f3, ethertype IPv6 (0x86dd), length 182: fc00:b::b > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:49:06.204192 e6:a1:18:75:81:f8 > ea:39:ee:f6:8f:f3, ethertype IPv6 (0x86dd), length 182: fc00:b::b > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:49:06.204198 ea:39:ee:f6:8f:f3 > e6:a1:18:75:81:f8, ethertype IPv6 (0x86dd), length 118: fc00:b::10 > fc00:a::10: ICMP6, echo reply, seq 17, length 64
^C
```

```
sudo ip netns exec host3Y tcpdump -n -e -l -i veth3D
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on veth3D, link-type EN10MB (Ethernet), capture size 262144 bytes
12:57:47.782556 5e:fe:c3:7a:0d:b6 > 26:6f:fc:6a:83:9c, ethertype IPv6 (0x86dd), length 182: fc00:a::a > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:57:47.782583 5e:fe:c3:7a:0d:b6 > 26:6f:fc:6a:83:9c, ethertype IPv6 (0x86dd), length 182: fc00:a::a > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:57:47.782596 26:6f:fc:6a:83:9c > 5e:fe:c3:7a:0d:b6, ethertype IPv6 (0x86dd), length 118: fc00:a::10 > fc00:b::10: ICMP6, echo request, seq 1, length 64
12:57:47.782653 5e:fe:c3:7a:0d:b6 > 26:6f:fc:6a:83:9c, ethertype IPv6 (0x86dd), length 182: fc00:b::b > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:57:47.782657 5e:fe:c3:7a:0d:b6 > 26:6f:fc:6a:83:9c, ethertype IPv6 (0x86dd), length 182: fc00:b::b > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:57:47.782663 26:6f:fc:6a:83:9c > 5e:fe:c3:7a:0d:b6, ethertype IPv6 (0x86dd), length 118: fc00:b::10 > fc00:a::10: ICMP6, echo reply, seq 1, length 64
12:57:48.796061 5e:fe:c3:7a:0d:b6 > 26:6f:fc:6a:83:9c, ethertype IPv6 (0x86dd), length 182: fc00:a::a > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:57:48.796089 5e:fe:c3:7a:0d:b6 > 26:6f:fc:6a:83:9c, ethertype IPv6 (0x86dd), length 182: fc00:a::a > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:57:48.796102 26:6f:fc:6a:83:9c > 5e:fe:c3:7a:0d:b6, ethertype IPv6 (0x86dd), length 118: fc00:a::10 > fc00:b::10: ICMP6, echo request, seq 2, length 64
12:57:48.796158 5e:fe:c3:7a:0d:b6 > 26:6f:fc:6a:83:9c, ethertype IPv6 (0x86dd), length 182: fc00:b::b > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:57:48.796162 5e:fe:c3:7a:0d:b6 > 26:6f:fc:6a:83:9c, ethertype IPv6 (0x86dd), length 182: fc00:b::b > fc00:3::10: srcrt (len=2, type=4, segleft=0[|srcrt]
12:57:48.796168 26:6f:fc:6a:83:9c > 5e:fe:c3:7a:0d:b6, ethertype IPv6 (0x86dd), length 118: fc00:b::10 > fc00:a::10: ICMP6, echo reply, seq 2, length 64
^C
```
### routerAのzebraに接続方法

```
ip netns exec routerA telnet localhost 2601
Trying ::1...
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.

Hello, this is Quagga (version 1.1.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.


User Access Verification

Password:
routerA> en
routerA# show ipv6 route
Codes: K - kernel route, C - connected, S - static, R - RIPng,
       O - OSPFv6, I - IS-IS, B - BGP, A - Babel,
       > - selected route, * - FIB route

C>* ::1/128 is directly connected, lo
O>* fc00:3::/64 [110/30] via fe80::b839:d7ff:fef2:6f56, vethAC, 00:04:38
O   fc00:a::/64 [110/10] is directly connected, vethA1, 00:04:38
C>* fc00:a::/64 is directly connected, vethA1
O>* fc00:b::/64 [110/30] via fe80::4884:f5ff:fee6:8554, vethAD, 00:04:33
  *                      via fe80::b839:d7ff:fef2:6f56, vethAC, 00:04:33
K>* fc00:b::10/128 is directly connected, vethA1
O   fc00:ac::/64 [110/10] is directly connected, vethAC, 00:04:43
C>* fc00:ac::/64 is directly connected, vethAC
O   fc00:ad::/64 [110/10] is directly connected, vethAD, 00:04:38
C>* fc00:ad::/64 is directly connected, vethAD
O>* fc00:bc::/64 [110/20] via fe80::b839:d7ff:fef2:6f56, vethAC, 00:04:38
O>* fc00:bd::/64 [110/20] via fe80::4884:f5ff:fee6:8554, vethAD, 00:04:38
O>* fc00:c3::/64 [110/20] via fe80::b839:d7ff:fef2:6f56, vethAC, 00:04:38
C * fe80::/64 is directly connected, vethAC
C * fe80::/64 is directly connected, vethAD
C>* fe80::/64 is directly connected, vethA1
```

### routerAのospfv3に接続

```
ip netns exec routerA telnet ::1 2606
Trying ::1...
Connected to ::1.
Escape character is '^]'.

Hello, this is Quagga (version 1.1.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.


User Access Verification

Password:
routerA> en
routerA# show ipv
routerA# show ipv6 o
routerA# show ipv6 ospf6 rou
routerA# show ipv6 ospf6 route
*N IA fc00:3::/64                    fe80::b839:d7ff:fef2:6f56 vethAC 00:03:58
*N IA fc00:a::/64                    ::                        vethA1 00:03:58
*N IA fc00:b::/64                    fe80::4884:f5ff:fee6:8554 vethAD 00:03:53
                                     fe80::b839:d7ff:fef2:6f56 vethAC
*N IA fc00:ac::/64                   ::                        vethAC 00:04:03
*N IA fc00:ad::/64                   ::                        vethAD 00:03:58
*N IA fc00:bc::/64                   fe80::b839:d7ff:fef2:6f56 vethAC 00:03:58
*N IA fc00:bd::/64                   fe80::4884:f5ff:fee6:8554 vethAD 00:03:58
*N IA fc00:c3::/64                   fe80::b839:d7ff:fef2:6f56 vethAC 00:03:58
```




