# Docker 容器使用 cgroups 限制资源使用

## Linux control groups

Linux Cgroups(Control Groups) 可​​​让​​​您​​​为​​​系​​​统​​​中​​​所​​​运​​​行​​​任​​​务​​​（进​​​程​​​）的​​​用​​​户​​​定​​​义​​​组​​​群​​​分​​​配​​​资​​​源​​​ — 比​​​如​​​ CPU 时​​​间​​​、​​​系​​​统​​​内​​​存​​​、​​​网​​​络​​​带​​​宽​​​或​​​者​​​这​​​些​​​资​​​源​​​的​​​组​​​合​​​。​​​您​​​可​​​以​​​监​​​控​​​您​​​配​​​置​​​的​​​ cgroup，拒​​​绝​​​ cgroup 访​​​问​​​某​​​些​​​资​​​源​​​，甚​​​至​​​在​​​运​​​行​​​的​​​系​​​统​​​中​​​动​​​态​​​配​​​置​​​您​​​的​​​ cgroup。所以，可以将 controll groups 理解为 controller （system resource） （for） （process）groups，也就是是说它以一组进程为目标进行系统资源分配和控制。
Linux Cgroups(Control Groups) 提供了**对一组进程及将来的子进程的资源的限制**，控制和统计的能力，这些资源包括**CPU，内存，存储，网络**等。通过Cgroups，可以方便的限制某个进程的资源占用，并且可以实时的监控进程的监控和统计信息。

它主要提供了如下功能： 

- Resource limitation: 限制资源使用，比如内存使用上限以及文件系统的缓存限制。
- Prioritization: 优先级控制，比如：CPU利用和磁盘IO吞吐。
- Accounting: 一些审计或一些统计，主要目的是为了计费。
- Control: 挂起进程，恢复执行进程。

使​​​用​​​ cgroup，系​​​统​​​管​​​理​​​员​​​可​​​更​​​具​​​体​​​地​​​控​​​制​​​对​​​系​​​统​​​资​​​源​​​的分​​​配​​​、​​​优​​​先​​​顺​​​序​​​、​​​拒​​​绝​​​、​​​管​​​理​​​和​​​监​​​控​​​。​​​可​​​更​​​好​​​地​​​根​​​据​​​任​​​务​​​和​​​用​​​户​​​分​​​配​​​硬​​​件​​​资​​​源​​​，提​​​高​​​总​​​体​​​效​​​率​​​。

在实践中，系统管理员一般会利用CGroup做下面这些事（有点像为某个虚拟机分配资源似的）：

- 隔离一个进程集合（比如：nginx的所有进程），并限制他们所消费的资源，比如绑定CPU的核。
- 为这组进程分配其足够使用的内存
- 为这组进程分配相应的网络带宽和磁盘存储限制
- 限制访问某些设备（通过设置设备的白名单）

查看 linux 内核中是否启用了 cgroup：

```
vagrant@vagrant:~$ uname -r
4.4.0-101-generic
vagrant@vagrant:~$ cat /boot/config-4.4.0-101-generic | grep CGROUP
CONFIG_CGROUPS=y
# CONFIG_CGROUP_DEBUG is not set
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_CGROUP_HUGETLB=y
CONFIG_CGROUP_PERF=y
CONFIG_CGROUP_SCHED=y
CONFIG_BLK_CGROUP=y
# CONFIG_DEBUG_BLK_CGROUP is not set
CONFIG_CGROUP_WRITEBACK=y
CONFIG_NETFILTER_XT_MATCH_CGROUP=m
CONFIG_NET_CLS_CGROUP=m
CONFIG_CGROUP_NET_PRIO=y
CONFIG_CGROUP_NET_CLASSID=y
```

对应的 cgroup 的配置值如果是 'y'，则表示已经被启用了。

Linux 系统中，一切皆文件。Linux 也将 cgroups 实现成了文件系统，方便用户使用:

```
vagrant@vagrant:~$ mount -t cgroup
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,nosuid,nodev,noexec,relatime,xattr,release_agent=/lib/systemd/systemd-cgroups-agent,name=systemd)
cgroup on /sys/fs/cgroup/devices type cgroup (rw,nosuid,nodev,noexec,relatime,devices)
cgroup on /sys/fs/cgroup/perf_event type cgroup (rw,nosuid,nodev,noexec,relatime,perf_event)
cgroup on /sys/fs/cgroup/net_cls,net_prio type cgroup (rw,nosuid,nodev,noexec,relatime,net_cls,net_prio)
cgroup on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,blkio)
cgroup on /sys/fs/cgroup/hugetlb type cgroup (rw,nosuid,nodev,noexec,relatime,hugetlb)
cgroup on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,cpuset)
cgroup on /sys/fs/cgroup/pids type cgroup (rw,nosuid,nodev,noexec,relatime,pids)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpu,cpuacct)
cgroup on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)

vagrant@vagrant:~$ lssubsys -m
cpuset /sys/fs/cgroup/cpuset
cpu,cpuacct /sys/fs/cgroup/cpu,cpuacct
blkio /sys/fs/cgroup/blkio
memory /sys/fs/cgroup/memory
devices /sys/fs/cgroup/devices
freezer /sys/fs/cgroup/freezer
net_cls,net_prio /sys/fs/cgroup/net_cls,net_prio
perf_event /sys/fs/cgroup/perf_event
hugetlb /sys/fs/cgroup/hugetlb
pids /sys/fs/cgroup/pids

vagrant@vagrant:~$ ls -l /sys/fs/cgroup/
total 0
dr-xr-xr-x 6 root root  0 Jun 30 09:35 blkio
lrwxrwxrwx 1 root root 11 Jun 22 23:10 cpu -> cpu,cpuacct
lrwxrwxrwx 1 root root 11 Jun 22 23:10 cpuacct -> cpu,cpuacct
dr-xr-xr-x 6 root root  0 Jun 30 09:35 cpu,cpuacct
dr-xr-xr-x 3 root root  0 Jun 30 09:35 cpuset
dr-xr-xr-x 6 root root  0 Jun 30 09:35 devices
dr-xr-xr-x 3 root root  0 Jun 30 09:35 freezer
dr-xr-xr-x 3 root root  0 Jun 30 09:35 hugetlb
dr-xr-xr-x 6 root root  0 Jun 30 09:35 memory
lrwxrwxrwx 1 root root 16 Jun 22 23:10 net_cls -> net_cls,net_prio
dr-xr-xr-x 3 root root  0 Jun 30 09:35 net_cls,net_prio
lrwxrwxrwx 1 root root 16 Jun 22 23:10 net_prio -> net_cls,net_prio
dr-xr-xr-x 3 root root  0 Jun 30 09:35 perf_event
dr-xr-xr-x 6 root root  0 Jun 30 09:35 pids
dr-xr-xr-x 6 root root  0 Jun 30 09:35 systemd
```

## Cgroups中的三个组件

### cgroup
cgroup 是对进程分组管理的一种机制，一个cgroup包含一组进程，并可以在这个cgroup上增加Linux subsystem的各种参数的配置，将一组进程和一组subsystem的系统参数关联起来。

### subsystem

subsystem 是一组资源控制的模块，一般包含有：

- blkio 设置对块设备（比如硬盘）的输入输出的访问控制
- cpu 设置cgroup中的进程的CPU被调度的策略
- cpuacct 可以统计cgroup中的进程的CPU占用
- cpuset 在多核机器上设置cgroup中的进程可以使用的CPU和内存（此处内存仅使用于NUMA架构）
- devices 控制cgroup中进程对设备的访问
- freezer 用于挂起(suspends)和恢复(resumes) cgroup中的进程
- memory 用于控制cgroup中进程的内存占用
- net_cls 用于将cgroup中进程产生的网络包分类(classify)，以便Linux的tc(traffic controller) 可以根据分类(classid)区分出来自某个cgroup的包并做限流或监控。
- net_prio 设置cgroup中进程产生的网络流量的优先级
- ns 这个subsystem比较特殊，它的作用是cgroup中进程在新的namespace fork新进程(NEWNS)时，创建出一个新的cgroup，这个cgroup包含新的namespace中进程。

 net_cls 和 tc 一起使用可用于限制进程发出的网络包所使用的网络带宽。当使用 cgroups network controll net_cls 后，指定进程发出的所有网络包都会被加一个 tag，然后就可以使用其他工具比如 iptables 或者 traffic controller （TC）来根据网络包上的 tag 进行流量控制。关于 TC 的文档，网上很多，这里不再赘述。

每个subsystem会关联到定义了相应限制的cgroup上，并对这个cgroup中的进程做相应的限制和控制，这些subsystem是逐步合并到内核中的，如何看到当前的内核支持哪些subsystem呢？可以安装cgroup的命令行工具(apt-get install cgroup-bin)，然后通过lssubsys看到kernel支持的subsystem。 


### hierarchy
hierarchy 的功能是把一组cgroup串成一个树状的结构，一个这样的树便是一个hierarchy，通过这种树状的结构，Cgroups可以做到继承。比如我的系统对一组定时的任务进程通过cgroup1限制了CPU的使用率，然后其中有一个定时dump日志的进程还需要限制磁盘IO，为了避免限制了影响到其他进程，就可以创建cgroup2继承于cgroup1并限制磁盘的IO，这样cgroup2便继承了cgroup1中的CPU的限制，并且又增加了磁盘IO的限制而不影响到cgroup1中的其他进程。

### 三个组件相互的关系

Cgroups的是靠这三个组件的相互协作实现的，那么这三个组件是什么关系呢？ 

- 系统在创建新的hierarchy之后，系统中所有的进程都会加入到这个hierarchy的根cgroup节点中，这个cgroup根节点是hierarchy默认创建，后面在这个hierarchy中创建cgroup都是这个根cgroup节点的子节点。
- 一个subsystem只能附加到一个hierarchy上面
- 一个hierarchy可以附加多个subsystem
- 一个进程可以作为多个cgroup的成员，但是这些cgroup必须是在不同的hierarchy中
- 一个进程fork出子进程的时候，子进程是和父进程在同一个cgroup中的，也可以根据需要将其移动到其他的cgroup中。

Cgroups中的hierarchy是一种树状的组织结构，Kernel为了让对Cgroups的配置更直观，Cgroups通过一个虚拟的树状文件系统去做配置的，通过层级的目录虚拟出cgroup树。

### 术语

- 任务（Tasks）：就是系统的一个进程。
- 控制组（Control Group）：一组按照某种标准划分的进程，比如官方文档中的Professor和Student，或是WWW和System之类的，其表示了某进程组。Cgroups中的资源控制都是以控制组为单位实现。一个进程可以加入到某个控制组。而资源的限制是定义在这个组上，就像上面示例中我用的 hello 一样。简单点说，cgroup的呈现就是一个目录带一系列的可配置文件。
- 层级（Hierarchy）：控制组可以组织成hierarchical的形式，既一颗控制组的树（目录结构）。控制组树上的子节点继承父结点的属性。简单点说，hierarchy就是在一个或多个子系统上的cgroups目录树。
- 子系统（Subsystem）：一个子系统就是一个资源控制器，比如CPU子系统就是控制CPU时间分配的一个控制器。子系统必须附加到一个层级上才能起作用，一个子系统附加到某个层级以后，这个层级上的所有控制族群都受到这个子系统的控制。Cgroup的子系统可以有很多，也在不断增加中。

## 实验

### 通过 cgroups 限制进程的 CPU

```c
int main(void)
{
    int i = 0;
    for(;;) i++;
    return 0;
}
```

运行之后，发现cpu占用几乎100%：

```
top - 16:06:57 up 7 days, 16:53,  2 users,  load average: 0.82, 0.27, 0.10
Tasks:   1 total,   1 running,   0 sleeping,   0 stopped,   0 zombie
%Cpu(s):100.0 us,  0.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  4046588 total,   594524 free,   537964 used,  2914100 buff/cache
KiB Swap:  1048572 total,  1048480 free,       92 used.  3070952 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
31208 vagrant   20   0    4220    724    656 R 99.3  0.0   1:06.14 a.out
```

接下来配置cgroup:

```bash
mkdir /sys/fs/cgroup/cpu/hello
cd /sys/fs/cgroup/cpu/hello
cat cpu.cfs_quota_us // 默认创建hello目录之后，自动创建cfs相关文件
echo 20000 > cpu.cfs_quota_us // 若非root用户，需sudo sh -c "echo 20000 > cpu.cfs_quota_us"
echo 31208 > tasks // 31208为上面c程序进程id
```

然后再来看看这个进程的 CPU 占用情况:

```
Tasks: 152 total,   2 running, 150 sleeping,   0 stopped,   0 zombie
%Cpu(s): 17.1 us,  0.0 sy,  0.0 ni, 82.9 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  4046588 total,   592952 free,   539276 used,  2914360 buff/cache
KiB Swap:  1048572 total,  1048480 free,       92 used.  3069628 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
31208 vagrant   20   0    4220    724    656 R 19.9  0.0   6:02.71 a.out
```

它占用的 CPU 几乎就是 20%，也就是我们预设的阈值。这说明我们通过上面的步骤，成功地将这个进程运行所占用的 CPU 资源限制在某个阈值之内了。

如果此时再启动另一个进程并将其 id 加入 tasks 文件(sudo sh -c "echo 31618 >> tasks)，则**两个进程会共享设定的 CPU 限制**，即每个进程各占10%的cpu资源：

```
top - 16:17:51 up 7 days, 17:04,  4 users,  load average: 1.39, 1.24, 0.71
Tasks: 158 total,   3 running, 155 sleeping,   0 stopped,   0 zombie
%Cpu(s): 18.6 us,  0.3 sy,  0.0 ni, 81.1 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  4046588 total,   578088 free,   550312 used,  2918188 buff/cache
KiB Swap:  1048572 total,  1048480 free,       92 used.  3058200 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
31618 vagrant   20   0    4220    648    580 R 10.0  0.0   2:43.16 a.out
31208 vagrant   20   0    4220    724    656 R  9.6  0.0   7:04.75 a.out
```

### 通过 cgroups 限制进程的 Memory

```
vagrant@vagrant:~$ cd /sys/fs/cgroup/memory
vagrant@vagrant:/sys/fs/cgroup/memory$ sudo mkdir hello
vagrant@vagrant:/sys/fs/cgroup/memory$ cd hello/
vagrant@vagrant:/sys/fs/cgroup/memory/hello$ cat memory.limit_in_bytes
9223372036854771712
vagrant@vagrant:/sys/fs/cgroup/memory/hello$ sudo sh -c "echo 64k > memory.limit_in_bytes"
vagrant@vagrant:/sys/fs/cgroup/memory/hello$ cat memory.limit_in_bytes
65536
vagrant@vagrant:/sys/fs/cgroup/memory/hello$ sudo sh -c "echo 31208 > tasks" // 将进程31208加入到task文件中
```
进程31208占用的内存阈值设置为 64K。超过的话，它会被杀掉。

### 限制进程的 I/O

查看io速度：

```
vagrant@vagrant:~$ sudo dd if=/dev/sda1 of=/dev/null
997376+0 records in
997376+0 records out
510656512 bytes (511 MB, 487 MiB) copied, 0.497896 s, 1.0 GB/s
```
然后通过 iotop 命令观察 IO

接着做下面的操作：

```
mkdir /sys/fs/cgroup/blkio/io
cd /sys/fs/cgroup/blkio/io
ls -l /dev/sda1
brw-rw---- 1 root disk 8, 1 Jun 22 23:10 /dev/sda1

echo '8:0 1048576'  > /sys/fs/cgroup/blkio/io/blkio.throttle.read_bps_device
echo 2725 > /sys/fs/cgroup/blkio/io/tasks
```

## Docker 对 cgroups 的使用

默认情况下，Docker 启动一个容器后，会在 /sys/fs/cgroup 目录下的各个资源目录下生成以容器 ID 为名字的目录（group），比如：

> /sys/fs/cgroup/cpu/docker/da577b6b5bc89ae28080778bf8e3d7560b32d1efaf499cff7f414ca2ca7d4ca5

此时 cpu.cfs_quota_us 的内容为 -1，表示默认情况下并没有限制容器的 CPU 使用。在容器被 stopped 后，该目录被删除。

### 限制容器可用的 CPU

#### 限制可用的 CPU 个数

docker 1.13 及更高的版本上，能够很容易的限制容器可以使用的主机 CPU 个数。只需要通过 --cpus 选项指定容器可以使用的 CPU 个数就可以了，并且还可以指定如 1.5 之类的小数。

创建测试镜像(docker build -t mystress:latest .)：

```
FROM ubuntu:latest

RUN apt-get update && apt-get install -y stress
```

指定使用2个CPU：

```
docker run -it --rm --cpus=2 mystress:latest /bin/bash

stress -c 4
```

通过docker stats命令可以查看到大概占用2个cpu：

```
CONTAINER ID   NAME               CPU %     MEM USAGE / LIMIT     MEM %     NET I/O         BLOCK I/O   PIDS
6f2d12f0183e   inspiring_spence   200.89%   2.199MiB / 7.771GiB   0.03%     1.03kB / 138B   0B / 0B     6
```

需要注意的是对于进程来说是没有 CPU 个数这一概念的，内核只能通过进程消耗的 CPU 时间片来统计出进程占用 CPU 的百分比。上面CPU%为200.11%，说明该进程占用2个CPU。对于4核心的系统，但这不意味着有2个cpu使用100%，另外两个使用0%。实际上是每个CPU都会使用，即每个核心使用了50%:

```
top - 17:55:34 up 7 min,  2 users,  load average: 0.21, 0.20, 0.11
Tasks: 179 total,   5 running, 174 sleeping,   0 stopped,   0 zombie
%Cpu0  : 50.7 us,  0.0 sy,  0.0 ni, 49.3 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu1  : 50.5 us,  0.0 sy,  0.0 ni, 49.5 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu2  : 50.5 us,  0.0 sy,  0.0 ni, 49.5 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu3  : 48.3 us,  0.7 sy,  0.0 ni, 51.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
```

更早的版本完成同样的功能我们需要配合使用两个选项：--cpu-period 和 --cpu-quota(1.13 及之后的版本仍然支持这两个选项)。下面的命令实现相同的结果：

```
ocker run -it --rm --cpu-period=100000 --cpu-quota=200000 mystress:latest /bin/bash
```
cpu-period, cpu-quota它们的单位是微秒，100000 表示 100 毫秒，200000 表示 200 毫秒。它们在这里的含义是：在每 100 毫秒的时间里，运行进程使用的 CPU 时间最多为 200 毫秒(需要两个 CPU 各执行 100 毫秒，需要两个 CPU 各执行 100 毫秒)。这两个参数含义参考[CFS BandWith Control](https://www.kernel.org/doc/Documentation/scheduler/sched-bwc.txt)

#### 指定固定的 CPU

通过 --cpus 选项我们无法让容器始终在一个或某几个 CPU 上运行，但是通过 --cpuset-cpus 选项却可以做到！这是非常有意义的，因为现在的多核系统中每个核心都有自己的缓存，如果频繁的调度进程在不同的核心上执行势必会带来缓存失效等开销。下面我们就演示如何设置容器使用固定的 CPU，下面的命令为容器设置了 --cpuset-cpus 选项，指定运行容器的 CPU 编号为 1

```
docker run -it --rm --cpuset-cpus="1" mystress:latest /bin/bash
stress -c 4 // 指定并发运行进程个数
```

查看CPU负载情况：

```
top - 17:56:58 up 9 min,  2 users,  load average: 1.30, 0.60, 0.26
Tasks: 182 total,   5 running, 177 sleeping,   0 stopped,   0 zombie
%Cpu0  :  0.3 us,  0.0 sy,  0.0 ni, 98.0 id,  0.0 wa,  0.0 hi,  1.6 si,  0.0 st
%Cpu1  :100.0 us,  0.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu2  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu3  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
```

这次只有 Cpu1 达到了 100%，其它的 CPU 并未被容器使用。我们还可以反复的执行 stress -c 4 命令，但是始终都是 Cpu1 在干活。再看看容器的 CPU 负载，也是只有 100%：

```
CONTAINER ID   NAME               CPU %     MEM USAGE / LIMIT     MEM %     NET I/O       BLOCK I/O   PIDS
20431b28c268   trusting_haslett   99.64%    1.746MiB / 7.771GiB   0.02%     1.02kB / 0B   0B / 0B     6
```

--cpuset-cpus 选项还可以一次指定多个 CPU：

```
docker run -it --rm --cpuset-cpus="1,3" mystress:latest /bin/bash
stress -c 4
```

观察CPU负载：

```
top - 18:02:19 up 14 min,  2 users,  load average: 1.72, 1.30, 0.72
Tasks: 177 total,   5 running, 172 sleeping,   0 stopped,   0 zombie
%Cpu0  :  0.3 us,  0.0 sy,  0.0 ni, 99.3 id,  0.0 wa,  0.0 hi,  0.3 si,  0.0 st
%Cpu1  :100.0 us,  0.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu2  :  0.3 us,  0.0 sy,  0.0 ni, 99.7 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu3  :100.0 us,  0.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   7957.8 total,   6286.8 free,    303.3 used,   1367.7 buff/cache
MiB Swap:      0.0 total,      0.0 free,      0.0 used.   7397.6 avail Mem

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
   5990 root      20   0    3864    100      0 R  52.8   0.0   0:13.81 stress
   5992 root      20   0    3864    100      0 R  51.2   0.0   0:13.68 stress
   5989 root      20   0    3864    100      0 R  47.8   0.0   0:13.98 stress
   5991 root      20   0    3864    100      0 R  47.5   0.0   0:13.57 stress
```

Cpu1 和 Cpu3 的负载都达到了 100%。容器的 CPU 负载也达到了 200%：

```
CONTAINER ID   NAME            CPU %     MEM USAGE / LIMIT     MEM %     NET I/O       BLOCK I/O   PIDS
5d1c1df38895   epic_einstein   200.29%   2.188MiB / 7.771GiB   0.03%     1.09kB / 0B   0B / 0B     6
```

#### 设置使用 CPU 的权重

当 CPU 资源充足时，设置 CPU 的权重是没有意义的。只有在容器争用 CPU 资源的情况下， CPU 的权重才能让不同的容器分到不同的 CPU 用量。--cpu-shares 选项用来设置 CPU 权重，它的默认值为 1024。我们可以把它设置为 2 表示很低的权重，但是设置为 0 表示使用默认值 1024。

分别运行两个容器，指定它们都使用 Cpu0，并分别设置 --cpu-shares 为 512 和 1024：

```
docker run -it --rm --cpuset-cpus="0" --cpu-shares=512 mystress:latest /bin/bash
docker run -it --rm --cpuset-cpus="0" --cpu-shares=1024 mystress:latest /bin/bash
```

此时主机 Cpu0 的负载为 100%：

```
top - 18:07:51 up 20 min,  3 users,  load average: 7.01, 4.08, 2.04
Tasks: 189 total,   9 running, 180 sleeping,   0 stopped,   0 zombie
%Cpu0  :100.0 us,  0.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu1  :  0.0 us,  0.0 sy,  0.0 ni, 98.4 id,  0.0 wa,  0.0 hi,  1.6 si,  0.0 st
%Cpu2  :  0.3 us,  0.0 sy,  0.0 ni, 99.7 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu3  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   7957.8 total,   6247.2 free,    341.5 used,   1369.1 buff/cache
MiB Swap:      0.0 total,      0.0 free,      0.0 used.   7363.8 avail Mem

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
   6450 root      20   0    3864    100      0 R  15.9   0.0   0:05.70 stress
   6451 root      20   0    3864    100      0 R  15.9   0.0   0:05.70 stress
   6452 root      20   0    3864    100      0 R  15.9   0.0   0:05.70 stress
   6453 root      20   0    3864    100      0 R  15.9   0.0   0:05.70 stress
   6302 root      20   0    3864    104      0 R   9.3   0.0   0:20.40 stress
   6304 root      20   0    3864    104      0 R   9.3   0.0   0:20.40 stress
   6301 root      20   0    3864    104      0 R   9.0   0.0   0:20.39 stress
   6303 root      20   0    3864    104      0 R   9.0   0.0   0:20.39 stress
```
容器中 CPU 的负载为：

```
CONTAINER ID   NAME             CPU %     MEM USAGE / LIMIT     MEM %     NET I/O       BLOCK I/O   PIDS
31d1800d6a7d   brave_shannon    36.16%    1.699MiB / 7.771GiB   0.02%     1.02kB / 0B   0B / 0B     6
c325fadb8d2c   nervous_edison   62.92%    1.816MiB / 7.771GiB   0.02%     586B / 0B     0B / 0B     6
```

两个容器分享一个 CPU，所以总量应该是 100%。具体每个容器分得的负载则取决于 --cpu-shares 选项的设置！我们的设置分别是 512 和 1024，则它们分得的比例为 1:2。在本例中如果想让两个容器各占 50%，只要把 --cpu-shares 选项设为相同的值就可以了。

需要注意： **cgroup 只能限制 CPU 的使用，而不能保证CPU的使用**。也就是说， 使用 cpuset-cpus，可以让容器在指定的CPU或者核上运行，但是不能确保它独占这些CPU；**cpu-shares 是个相对值，只有在CPU不够用的时候才其作用**。也就是说，当CPU够用的时候，每个容器会分到足够的CPU；不够用的时候，会按照指定的比重在多个容器之间分配CPU

### 限制容器可用的内存

#### 为什么要限制容器对内存的使用？

限制容器不能过多的使用主机的内存是非常重要的。对于 linux 主机来说，一旦内核检测到没有足够的内存可以分配，就会扔出 OOME(Out Of Memmory Exception)，并开始杀死一些进程用于释放内存空间。糟糕的是任何进程都可能成为内核猎杀的对象，包括 docker daemon 和其它一些重要的程序。更危险的是如果某个支持系统运行的重要进程被干掉了，整个系统也就宕掉了！这里我们考虑一个比较常见的场景，大量的容器把主机的内存消耗殆尽，OOME 被触发后系统内核立即开始杀进程释放内存。如果内核杀死的第一个进程就是 docker daemon 会怎么样？结果是没有办法管理运行中的容器了，这是不能接受的！
针对这个问题，docker 尝试通过调整 docker daemon 的 OOM 优先级来进行缓解。内核在选择要杀死的进程时会对所有的进程打分，直接杀死得分最高的进程，接着是下一个。当 docker daemon 的 OOM 优先级被降低后(注意容器进程的 OOM 优先级并没有被调整)，docker daemon 进程的得分不仅会低于容器进程的得分，还会低于其它一些进程的得分。这样 docker daemon 进程就安全多了。
我们可以通过下面的脚本直观的看一下当前系统中所有进程的得分情况：

```bash
#!/bin/bash
for proc in $(find /proc -maxdepth 1 -regex '/proc/[0-9]+'); do
    printf "%2d %5d %s\n" \
        "$(cat $proc/oom_score)" \
        "$(basename $proc)" \
        "$(cat $proc/cmdline | tr '\0' ' ' | head -c 50)"
done 2>/dev/null | sort -nr | head -n 40
```

有了上面的机制后是否就可以高枕无忧了呢！不是的，docker 的官方文档中一直强调这只是一种缓解的方案，并且为我们提供了一些降低风险的建议：

- 通过测试掌握应用对内存的需求
- 保证运行容器的主机有充足的内存
- 限制容器可以使用的内存
- 为主机配置 swap


#### 限制内存使用上限

-m(--memory=) 选项可以完成限制内存使用上限的配置：

```
docker run -it -m 300M --memory-swap -1 --name test1 mystress /bin/bash
```

stress 命令会创建一个进程并通过 malloc 函数分配内存：

```
stress --vm 1 --vm-bytes 500M
```

通过 docker stats 命令查看实际情况：

```
CONTAINER ID   NAME      CPU %     MEM USAGE / LIMIT   MEM %     NET I/O       BLOCK I/O   PIDS
5a2eff8a21d0   test1     0.00%     1.758MiB / 300MiB   0.59%     1.02kB / 0B   0B / 0B     1
```

上面的 docker run 命令中通过 -m 选项限制容器使用的内存上限为 300M。同时设置 memory-swap 值为 -1，它表示容器程序使用内存的受限，而可以使用的 swap 空间使用不受限制(宿主机有多少 swap 容器就可以使用多少)。
下面我们通过 top 命令来查看 stress 进程内存的实际情况:

上面的截图中先通过 pgrep 命令查询 stress 命令相关的进程，进程号比较大的那个是用来消耗内存的进程，我们就查看它的内存信息。VIRT 是进程虚拟内存的大小，所以它应该是 500M。RES 为实际分配的物理内存数量，我们看到这个值就在 300M 上下浮动。看样子我们已经成功的限制了容器能够使用的物理内存数量。

#### 限制可用的 swap 大小
强调一下 --memory-swap 是必须要与 --memory 一起使用的。正常情况下， --memory-swap 的值包含容器可用内存和可用 swap。所以 --memory="300m" --memory-swap="1g" 的含义为：

容器可以使用 300M 的物理内存，并且可以使用 700M(1G -300M) 的 swap。--memory-swap 居然是容器可以使用的物理内存和可以使用的 swap 之和！把 --memory-swap 设置为 0 和不设置是一样的，此时如果设置了 --memory，容器可以使用的 swap 大小为 --memory 值的两倍。

### go语言实现通过cgroup限制容器的资源

```go
package main
 
import (
    "os/exec"
    "path"
    "os"
    "fmt"
    "io/ioutil"
    "syscall"
    "strconv"
)
 
const cgroupMemoryHierarchyMount = "/sys/fs/cgroup/memory"
 
func main() {
    if os.Args[0] == "/proc/self/exe" {
        //容器进程
        fmt.Printf("current pid %d", syscall.Getpid())
        fmt.Println()
        cmd := exec.Command("sh", "-c", `stress --vm-bytes 200m --vm-keep -m 1`)
        cmd.SysProcAttr = &syscall.SysProcAttr{
        }
        cmd.Stdin = os.Stdin
        cmd.Stdout = os.Stdout
        cmd.Stderr = os.Stderr
 
        if err := cmd.Run(); err != nil {
            fmt.Println(err)
            os.Exit(1)
        }
    }
    
    cmd := exec.Command("/proc/self/exe")
    cmd.SysProcAttr = &syscall.SysProcAttr{
        Cloneflags: syscall.CLONE_NEWUTS | syscall.CLONE_NEWPID | syscall.CLONE_NEWNS,
    }
    cmd.Stdin = os.Stdin
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
 
    if err := cmd.Start(); err != nil {
        fmt.Println("ERROR", err)
        os.Exit(1)
    } else {
        //得到fork出来进程映射在外部命名空间的pid
        fmt.Printf("%v", cmd.Process.Pid)
 
        // 在系统默认创建挂载了memory subsystem的Hierarchy上创建cgroup
        os.Mkdir(path.Join(cgroupMemoryHierarchyMount, "testmemorylimit"), 0755)
        // 将容器进程加入到这个cgroup中
        ioutil.WriteFile(path.Join(cgroupMemoryHierarchyMount, "testmemorylimit", "tasks") , []byte(strconv.Itoa(cmd.Process.Pid)), 0644)
        // 限制cgroup进程使用
        ioutil.WriteFile(path.Join(cgroupMemoryHierarchyMount, "testmemorylimit", "memory.limit_in_bytes") , []byte("100m"), 0644)
    }
    cmd.Process.Wait()
}
```

## 资料

- [Docker: 限制容器可用的 CPU](https://www.cnblogs.com/sparkdev/p/8052522.html)
- [Docker: 限制容器可用的内存](https://www.cnblogs.com/sparkdev/p/8032330.html)
- [Runtime options with Memory, CPUs, and GPUs](https://docs.docker.com/config/containers/resource_constraints/)
- [理解Docker（4）：Docker 容器使用 cgroups 限制资源使用](https://www.cnblogs.com/sammyliu/p/5886833.html)
- [《自己动手写Docker》书摘之二： Linux Cgroups](https://blog.csdn.net/weixin_34149796/article/details/90587655)



