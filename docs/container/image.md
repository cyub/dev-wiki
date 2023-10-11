# 镜像

镜像(image)是动态的容器的静态表示（specification），包括容器所要运行的应用代码以及运行时的配置。**Docker 镜像包括一个或者多个只读层（ read-only layers ）**，因此，镜像一旦被创建就再也不能被修改了。一个运行着的Docker 容器是一个镜像的实例（ instantiation ）。**每个运行着的容器都有一个可写层（ writable layer ，也成为容器层 container layer）**，它位于底下的若干只读层之上。运行时的所有变化，包括对数据和文件的写和更新，都会保存在这个层中。因此，**从同一个镜像运行的多个容器包含了不同的容器层**。

## Host OS VS Guest OS VS Base image

比如，一台主机安装的是 Centos 操作系统，现在在上面跑一个 Ubuntu 容器。此时，Host OS 是 Centos，Guest OS 是 Ubuntu。Guest OS 也被成为容器的 Base Image。

![](https://static.cyub.vip/images/202107/guest-os.png)

因为所有Linux发行版都包含同一个linux 内核（有轻微修改），以及不同的自己的软件，因此，会很容易地将某个 userland 软件安装在linux 内核上，来模拟不同的发行版环境。比如说，在 Ubuntu 上运行 Centos 容器，这意味着从 Centos 获取 userland 软件，运行在 Ubuntu 内核上。因此，这就像在同一个操作系统（linux 内核）上运行不同的 userland 软件（发行版的）。这就是为什么Docker 不支持在 Linux 主机上运行 FreeBSD 或者windows 容器。


## Dockerfile 语法

###  ADD 和 COPY

Add：将 host 上的文件拷贝到或者将网络上的文件下载到容器中的指定目录。

两者都可以从本地拷贝文件，那两者有什么区别呢？

1. ADD 多了2个功能, 下载URL和对支持的压缩格式的包进行解压.  其他都一样。比如 ADD http://foo.com/bar.go /tmp/main.go 会将文件从因特网上方下载下来，ADD /foo.tar.gz /tmp/ 会将压缩文件解压再COPY过去
2. 如果你不希望压缩文件拷贝到container后会被解压的话, 那么使用COPY。
3. 如果需要自动下载URL并拷贝到container的话, 请使用ADD

###  RUN

运行命令，结果会生成镜像中的一个新层

### VOLUME

允许容器访问host上某个目录

```
# Usage: VOLUME ["/dir_1", "/dir_2" ..]
VOLUME ["/my_files"]
```

### CMD

CMD：在容器被创建后执行的命令，和 RUN 不同，它是在构造容器时候所执行的命令

```
# Usage 1: CMD application "argument", "argument", ..
CMD "echo" "Hello docker!"
```

CMD 有三种格式:

- CMD ["executable","param1","param2"] (like an exec, preferred form)
- CMD ["param1","param2"] (作为 ENTRYPOINT 的参数)
- CMD command param1 param2 (作为 shell 运行)

一个Dockerfile里只能有一个CMD，如果有多个，只有最后一个生效。

### ENTRYPOINT

ENTRYPOINT ：设置默认应用，会保证每次容器被创建后该应用都会被执行。

CMD 和 ENTRYPOINT区别与联系？

- Dockerfile 至少需要指定一个 CMD 或者 ENTRYPOINT 指令
- CMD 可以用来指定 ENTRYPOINT 指令的参数
- CMD 和 ENTRYPOINT 都存在时，CMD 的指令作为 ENTRYPOINT 的参数

<i></i> |  没有 ENTRYPOINT  |  ENTRYPOINT exec_entry p1_entry  |  ENTRYPOINT [“exec_entry”, “p1_entry”]
--- | --- | --- | ---
没有 CMD  |  错误，不允许  |  /bin/sh -c exec_entry p1_entry  |   exec_entry p1_entry
CMD [“exec_cmd”, “p1_cmd”]  |   exec_cmd p1_cmd  |   /bin/sh -c exec_entry p1_entry exec_cmd p1_cmd  |   exec_entry p1_entry exec_cmd p1_cmd
CMD [“p1_cmd”, “p2_cmd”]  |   p1_cmd p2_cmd  |   /bin/sh -c exec_entry p1_entry p1_cmd p2_cmd  |   exec_entry p1_entry p1_cmd p2_cmd
CMD exec_cmd p1_cmd  |   /bin/sh -c exec_cmd p1_cmd  |   /bin/sh -c exec_entry p1_entry /bin/sh -c exec_cmd p1_cmd  |   exec_entry p1_entry /bin/sh -c exec_cmd p1_cmd
备注  |  只有 CMD 时，执行 CMD 定义的指令  |   CMD 和 ENTRYPOINT 都存在时，CMD 的指令作为 ENTRYPOINT 的参数



## docker与lxc是什么关系，有什么区别?

lxc 是早期版本 docker 的一个基础组件，docker 主要用到了它对 Cgroup 和 Namespace 两个内核特性的控制。随着 docker 的发展，它自己封装了 libcontainer （golang 的库）来实现 Cgroup 和 Namespace 控制，从而消除了对 lxc 的依赖。

Docker, LXC都是容器化的实现，底层都依赖内核的namespaces 和Cgroup，在多个方面又有很多不同。

## 资料

- [理解Docker（2）：Docker 镜像](https://www.cnblogs.com/sammyliu/p/5877964.html)