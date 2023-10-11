# Docker 安装和基础用法

## Docker 的基本操作

### Docker 容器的状态机

![](https://static.cyub.vip/images/202107/docker-status.jpeg)

一个容器在某个时刻可能处于以下几种状态之一：

- created：已经被创建 （使用 docker ps -a 命令可以列出）但是还没有被启动 （使用 docker ps 命令还无法列出）
- running：运行中
- paused：容器的进程被暂停了
- restarting：容器的进程正在重启过程中
- exited：上图中的 stopped 状态，表示容器之前运行过但是现在处于停止状态（要区别于 created 状态，它是指一个新创出的尚未运行过的容器）。可以通过 start 命令使其重新进入 running 状态
- destroyed：容器被删除了，再也不存在了

你可以在 docker inspect 命令的输出中查看其详细状态:

```
"State": {
            "Status": "running",
            "Running": true,
            "Paused": false,
            "Restarting": false,
            "OOMKilled": false,
            "Dead": false,
            "Pid": 4597,
            "ExitCode": 0,
            "Error": "",
            "StartedAt": "2016-09-16T08:09:34.53403504Z",
            "FinishedAt": "2016-09-16T08:06:44.365106765Z"
        }
```

### Docker 命令概述

1. 容器从生到死整个生命周期

```
root@devstack:/home/sammy# docker create --name web31 training/webapp python app.py  #创建名字为 web31 的容器
7465f4cb7c49555af32929bd1bc4213f5e72643c0116450e495b71c7ec128502
root@devstack:/home/sammy# docker inspect --format='{{.State.Status}}' web31 #其状态为 created
created
root@devstack:/home/sammy# docker start web31 #启动容器
web31root@devstack:/home/sammy# docker exec -it web31 /bin/bash #在容器中运行 bash 命令
root@devstack:/home/sammy# docker inspect --format='{{.State.Status}}' web31 #其状态为 running
running
root@devstack:/home/sammy# docker pause web31 #暂停容器
web31
root@devstack:/home/sammy# docker inspect --format='{{.State.Status}}' web31
paused
root@devstack:/home/sammy# docker unpause web31 #继续容器
web31
root@devstack:/home/sammy# docker inspect --format='{{.State.Status}}' web31
running
root@devstack:/home/sammy# docker rename web31 newweb31 #重命名
root@devstack:/home/sammy# docker inspect --format='{{.State.Status}}' newweb31
running
root@devstack:/home/sammy# docker top newweb31 #在容器中运行 top 命令
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD
root                5009                4979                0                   16:28               ?                   00:00:00            python app.py
root@devstack:/home/sammy# docker logs newweb31 #获取容器的日志
 * Running on http://0.0.0.0:5000/ (Press CTRL+C to quit)
root@devstack:/home/sammy# docker stop newweb31 #停止容器
newweb31
root@devstack:/home/sammy# docker inspect --format='{{.State.Status}}' newweb31
exited
root@devstack:/home/sammy# docker rm newweb31 #删除容器
newweb31
root@devstack:/home/sammy# docker inspect --format='{{.State.Status}}' newweb31
Error: No such image, container or task: newweb31
```

2. docker stop 和 docker kill

在docker stop 命令执行的时候，会先向容器中PID为1的进程发送系统信号 SIGTERM，然后等待容器中的应用程序终止执行，如果等待时间达到设定的超时时间（默认为 10秒，用户可以指定特定超时时长），会继续发送SIGKILL的系统信号强行kill掉进程。在容器中的应用程序，可以选择忽略和不处理SIGTERM信号，不过一旦达到超时时间，程序就会被系统强行kill掉，因为SIGKILL信号是直接发往系统内核的，应用程序没有机会去处理它。

比如运行 docker stop web5 -t 20 命令。

3. 使用 docker cp 在 host 和 container 之间拷贝文件或者目录


4. docker export 和 import

docker export：将一个容器的文件系统打包为一个压缩文件

```
root@devstack:/home/sammy# docker export web5 -o ./web5
root@devstack:/home/sammy# ls
chroot  devstack  Dockerfile  mongodbdocker  mydockerbuild  web5  webapp
```

docker import：从一个压缩文件创建一个镜像

```
root@devstack:/home/sammy# docker import web5 web5img -m "imported on 0916"
sha256:745bb258be0a69a517367667646148bb2f662565bb3d222b50c0c22e5274a926
root@devstack:/home/sammy# docker history web5img
IMAGE               CREATED             CREATED BY          SIZE                COMMENT
745bb258be0a        6 seconds ago
```

## 资料

- [Docker 安装和基础用法](https://www.cnblogs.com/sammyliu/p/5875470.html)