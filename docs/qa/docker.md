# docker

## Docker四种网络模式?

Docker网络模式 | 配置 | 说明
--- | --- | ---
host模式 | –net=host | 容器和宿主机共享Network namespace。该模式下容器是不会拥有自己的ip地址，而是**使用宿主机的ip地址和端口**。这种模式的好处就是**网络性能比桥接模式的好**。**缺点就是会占用宿主机的端口，网络的隔离性不太好**。
container模式 | –net=container:NAME_or_ID | 容器和另外一个容器共享Network namespace。kubernetes中的pod就是多个容器共享一个Network namespace。
none模式 | –net=none | 容器有独立的Network namespace，但并没有对其进行任何网络设置，如分配veth pair 和网桥连接，配置IP等。没有IP地址，无法连接外网，一般用于测试
bridge模式 | –net=bridge | （默认为该模式）


## Docker的bridge网络是如何工作的，以及如何进行内外网络通信的？

Docker容器创建时候默认会连接到docker0这个虚拟网桥(172.17.0.1)，并从docker0子网中分配一个IP给容器使用，并设置docker0的IP地址为容器的默认网关。在主机上创建一对虚拟网卡veth pair设备，Docker将veth pair设备的一端放在新创建的容器中，并命名为eth0（容器的网卡），另一端放在主机中，以vethxxx这样类似的名字命名，并将这个网络设备加入到docker0网桥中。可以通过brctl show命令查看。

![](https://static.cyub.vip/images/202107/docker-bridge.webp)

**如何与外部通信?**

![](https://static.cyub.vip/images/202107/docker-bridge-flow.png)

1. busybox 发送 ping 包：172.17.0.2 > www.baidu.com。

    docker0 收到包，发现是发送到外网的，交给 NAT 处理。

2. NAT 将源地址换成 enp0s3 的 IP：10.0.2.15 > www.bing.com。

3. ping 包从 enp0s3 发送出去，到达 www.bing.com。

**外部世界如何访问容器?**

一句话就是**端口映射**。

1. docker-proxy 监听 host 的 32773 端口。

2. 当 curl 访问 10.0.2.15:32773 时，docker-proxy转发给容器 172.17.0.2:80。

3. httpd 容器响应请求并返回结果。
