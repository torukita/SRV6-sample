# SRV6-sample

kernel 4.10からSRV6のkernel moduleが入った。  

- Ubuntu 17.04
- update iproute2

## 手順

### Ubuntu 17.04

 - インストール
 - package update

```
$ uname -r
4.10.0-30-generic
```

デフォルトでこんな感じ。  
```
$ sudo sysctl -a | grep seg6
sysctl: reading key "net.ipv6.conf.all.stable_secret"
net.ipv6.conf.all.seg6_enabled = 0
net.ipv6.conf.all.seg6_require_hmac = 0
sysctl: reading key "net.ipv6.conf.default.stable_secret"
net.ipv6.conf.default.seg6_enabled = 0
net.ipv6.conf.default.seg6_require_hmac = 0
sysctl: reading key "net.ipv6.conf.ens3.stable_secret"
net.ipv6.conf.ens3.seg6_enabled = 0
net.ipv6.conf.ens3.seg6_require_hmac = 0
sysctl: reading key "net.ipv6.conf.lo.stable_secret"
net.ipv6.conf.lo.seg6_enabled = 0
net.ipv6.conf.lo.seg6_require_hmac = 0
```
### iproute2

標準のipコマンドだと、seg6使えないので、置き換え。  

```
apt install build-essential
apt install autoconf
apt install pkg-config
apt install bison
```

```
git clone https://github.com/segment-routing/iproute2.git
cd iproute2
./configure
make
sudo make install
```

### 動作確認

namespaceディレクトリにサンプルスクリプト。  

```
cd namespace
sudo ./srv6-AB.sh
```

他に
 - srv6-ABC-I.sh
 - srv6-ABC-II.sh






