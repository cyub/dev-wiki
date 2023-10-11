# 网络

## Docker 网络架构

Docker 在 1.9 版本中引入了一整套的 docker network 子命令和跨主机网络支持。这允许用户可以根据他们应用的拓扑架构创建虚拟网络并将容器接入其所对应的网络。其实，早在 docker 1.7 版本中，网络部分代码就已经被抽离并单独成为了 docker 的网络库，即 libnetwork。在此之后，容器的网络模式也被抽象变成了统一接口的驱动。
为了标准化网络驱动的开发步骤和支持多种网络驱动，docker 公司在 libnetwork 中使用了 CNM(Container Network Model)。CNM 定义了构建容器虚拟化网络的模型，同时还提供了可以用于开发多种网络驱动的标准化接口和组件。Libnetwork 和 docker daemon 及各个网络驱动的关系可以通过下图形象的表示：

![](https://static.cyub.vip/images/202107/docker-network-model.png)

上图中，docker daemon 通过调用 libnetwork 对外提供的 API 完成网络的创建和管理等功能。Libnetwork 内部则使用了 CNM 来实现网络功能。CNM 中主要有沙盒(sandbox)、端点(endpoint) 和网络(network) 3 种组件。Libnetwork 中内置的 5 种驱动则为 libnetwork 提供了不同类型的网络服务。下面分别对 CNM 中的 3 个核心组件和 libnetwork 中的 5 种内置驱动进行介绍。

CNM 中的 3 个核心组件如下:

- 沙盒：一个沙盒包含了一个容器网络栈的信息。沙盒可以对容器的接口(interface)、路由和 DNS 设置等进行管理。沙盒的实现可以是 Linux network namespace、FreeBSD Jail 或者类似的机制。一个沙盒可以有多个端点和多个网络。
- 端点：一个端点可以加入一个沙盒和一个网络。端点的实现可以是 veth pair、Open vSwitch 内部端口或者相似的设备。一个端点可以属于一个网络并且只属于一个沙盒。
- 网络：一个网络是一组可以直接互相联通的端点。网络的实现可以是 Linux bridge、VLAN等。一个网络可以包含多个端点。


Libnetwork 中的 5 中内置驱动如下:

- bridge 驱动：这是 docker 设置的默认驱动。当使用 bridge 驱动时，libnetwork 将创建出来的 docker 容器连接到 docker0 网桥上。对于单机模式，bridge 驱动已经可以满足基本的需求了。但是这种模式下容器使用 NAT 方式与外界通信，这就增加了通信的复杂性。
- host 驱动：使用 host 驱动的时候，libnetwork 不会为容器创建网络协议栈，即不会创建独立的 network namespace。Docker 容器中的进程处于宿主机的网络环境中，相当于容器和宿主机共用同一个 network namespace，容器共享使用宿主机的网卡、IP 和端口等资源。Host 模式很好的解决了容器与外界通信的地址转换问题，可以直接使用宿主机的 IP 进行通信，不存在虚拟化网络带来的开销。但是 host 驱动也降低了容器与容器之间、容器与宿主机之间网络的隔离性，引起网络资源的竞争和冲突。因此可以认为 host 驱动适用于对容器集群规模不大的场景。
- overlay 驱动：overlay 驱动采用 IETF 标准的 VXLAN 方式，并且是 VXLAN 中被普遍认为最适合大规模的云计算虚拟化环境的 SDN controller 模式。在使用的过程中，还需要一个额外的配置存储服务，比如 Consul、etcd 或 ZooKeeper 等。并且在启动 docker daemon 的时候需要添加额外的参数来指定所使用的配置存储服务地址。
- remote 驱动：这个驱动实际上并未做真正的网络服务实现，而是调用了用户自行实现的网络驱动插件，是 libnetwork 实现了驱动的插件化，更好地满足了用户的多样化需求。用户只要根据 libnetwork 提供的协议标准实现其接口并注册即可。
- null 驱动：使用这种驱动的时候，docker 容器拥有字段的 network namespace，但是并不为 docker 容器进行任何网络配置。也就是说，这个容器除了 network namespace 自带的 loopback 网卡外，没有任何其它网卡、IP、路由等信息，需要用户为该容器添加网卡、配置 IP 等。这种模式如果不进行特定的配置是无法正常使用网络的，但是优点也非常明显，它给了用户最大的自由度来自定义容器的网络环境。

## 资料

- [Docker 网络之进阶篇](https://www.cnblogs.com/sparkdev/p/9198109.html)
- [理解Docker（5）：Docker 网络](https://www.cnblogs.com/sammyliu/p/5894191.html)