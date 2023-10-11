# Docker 使用 Linux namespace 隔离容器的运行环境

## Linux namespace

Linux 内核从版本 2.4.19 开始陆续引入了 namespace 的概念。其目的是将某个特定的全局系统资源（global system resource）通过抽象方法使得namespace 中的进程看起来拥有它们自己的隔离的全局系统资源实例（The purpose of each namespace is to wrap a particular global system resource in an abstraction that makes it appear to the processes within the namespace that they have their own isolated instance of the global resource. ）。Linux 内核中实现了六种 namespace，按照引入的先后顺序，列表如下：

namespace | 引入的相关内核版本 | 被隔离的全局系统资源 | 在容器语境下的隔离效果
--- | --- | --- | ---
Mount namespaces | Linux 2.4.19 | 文件系统挂接点 | 每个容器能看到不同的文件系统层次结构
UTS namespaces | Linux 2.6.19 | nodename 和 domainname | 每个容器可以有自己的 hostname 和 domainame
IPC namespaces | Linux 2.6.19 | 特定的进程间通信资源，包括System V IPC 和  POSIX message queues | 每个容器有其自己的 System V IPC 和 POSIX 消息队列文件系统，因此，只有在同一个 IPC namespace 的进程之间才能互相通信
PID namespaces | Linux 2.6.24 | 进程 ID 数字空间 （process ID number space） | 每个 PID namespace 中的进程可以有其独立的 PID； 每个容器可以有其 PID 为 1 的root 进程；也使得容器可以在不同的 host 之间迁移，因为 namespace 中的进程 ID 和 host 无关了。这也使得容器中的每个进程有两个PID：容器中的 PID 和 host 上的 PID。
Network namespaces | 始于Linux 2.6.24 完成于 Linux 2.6.29 | 网络相关的系统资源 | 每个容器用有其独立的网络设备，IP 地址，IP 路由表，/proc/net 目录，端口号等等。这也使得一个 host 上多个容器内的同一个应用都绑定到各自容器的 80 端口上。
User namespaces | 始于 Linux 2.6.23 完成于 Linux 3.8) | 用户和组 ID 空间 |  在 user namespace 中的进程的用户和组 ID 可以和在 host 上不同； 每个 container 可以有不同的 user 和 group id；一个 host 上的非特权用户可以成为 user namespace 中的特权用户；

Linux namespace 的概念说简单也简单说复杂也复杂。简单来说，我们只要知道，处于某个 namespace 中的进程，能看到独立的它自己的隔离的某些特定系统资源；复杂来说，可以去看看 Linux 内核中实现 namespace 的原理。

## Docker 容器使用 linux namespace 做运行环境隔离

当 Docker 创建一个容器时，它会创建新的以上六种 namespace 的实例，然后把容器中的所有进程放到这些 namespace 之中，使得Docker 容器中的进程只能看到隔离的系统资源。

### PID namespace

我们能看到同一个进程，在容器内外（容器内核host上）的 PID 是不同的：

在容器内 PID 是 1，PPID 是 0。
在容器外 PID 是 2198， PPID 是 2179 即 docker-containerd-shim 进程.


关于 containerd，containerd-shim 和 container 的关系，文章 中的下图可以说明：

![](https://static.cyub.vip/images/202107/docker-shim.jpeg)

- Docker 引擎管理着镜像，然后移交给 containerd 运行，containerd 再使用 runC 运行容器。
- Containerd 是一个简单的守护进程，它可以使用 runC 管理容器，使用 gRPC 暴露容器的其他功能。它管理容器的开始，停止，暂停和销毁。由于容器运行时是孤立的引擎，引擎最终能够启动和升级而无需重新启动容器。
- runC是一个轻量级的工具，它是用来运行容器的，只用来做这一件事，并且这一件事要做好。runC基本上是一个小命令行工具且它可以不用通过Docker引擎，直接就可以使用容器。

因此，容器中的主应用在 host 上的父进程是 containerd-shim，是它通过工具 runC 来启动这些进程的。这也能看出来，pid namespace 通过将 host 上 PID 映射为容器内的 PID， 使得容器内的进程看起来有个独立的 PID 空间。

### UTS namespace

容器可以有自己的 hostname 和 domainname

### user namespace

####  Linux 内核中的 user namespace

老版本中，Linux 内核里面只有一个数据结构负责处理用户和组。内核从3.8 版本开始实现了 user namespace。通过在 clone() 系统调用中使用 CLONE_NEWUSER 标志，一个单独的 user namespace 就会被创建出来。在新的 user namespace 中，有一个虚拟的用户和用户组的集合。**这些用户和用户组，从 uid/gid 0 开始，被映射到该 namespace 之外的 非 root 用户**。
 
在现在的linux内核中，管理员可以创建成千上万的用户。这些用户可以被映射到每个 user namespace 中。通过使用 user namespace 功能，不同的容器可以有完全不同的 uid 和 gid 数字。**容器 A 中的 User 500 可能被映射到容器外的 User 1500，而容器 B 中的 user 500 可能被映射到容器外的用户 2500**.
 
为什么需要这么做呢？因为在容器中，提供 root 访问权限有其特殊用途。想象一下，容器 A 中的 root 用户 （uid 0） 被映射到宿主机上的 uid 1000，容器B 中的 root 被映射到 uid 2000.类似网络端口映射，这允许管理员在容器中创建 root 用户，而不需要在宿主机上创建。 

#### Docker 对 user namespace 的支持

User namespace是从docker1.10开始被支持,并且不是默认开启的，即容器内的进程的运行用户就是 host 上的 root 用户，这样的话，当 host 上的文件或者目录作为 volume 被映射到容器以后，容器内的进程其实是有 root 的几乎所有权限去修改这些 host 上的目录的，这会有很大的安全问题。如何开启参见后面资料连接。

## 检查 linux 操作系统是否启用了 user namespace

```
vagrant@vagrant:~$  uname -a
Linux vagrant 4.4.0-101-generic #124-Ubuntu SMP Fri Nov 10 18:29:59 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux

vagrant@vagrant:~$ cat /boot/config-4.4.0-101-generic | grep CONFIG_USER_NS
CONFIG_USER_NS=y
```

如果是 「y」，则启用了，否则未启用。同样地，可以查看其它 namespace：

```
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_NET_NS=y
```

## 资料

- [理解Docker（3）：Docker 使用 Linux namespace 隔离容器的运行环境](https://www.cnblogs.com/sammyliu/p/5878973.html)