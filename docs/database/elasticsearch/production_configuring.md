Elasticsearch在生产环境部署时候，我们需要考虑系统配置优化和Es本身配置优化，已达到能够发挥其最佳性能。本文是根据官方文档和个人工作实践总结出的生产环境配置。

![](https://static.cyub.vip/images/202010/es_prod_config.jpg)

<!--more-->

## 生产环境配置

### 系统配置

Elasticsearch应该完全占用服务器资源，尽量不要再部署其他服务。系统配置方面应该考虑一下几个方面:

- 禁用内存交换(Disable swapping)
- 增加文件描述符(Increase file descriptors)
- 确保有足够的虚拟内存(Ensure sufficient virtual memory)
- 确保足够的线程(Ensure sufficient threads)

### 禁止内存交换

内存交换到磁盘对性能，节点稳定性非常不利，应不惜一切代价避免交换。它可能导致垃圾收集持续数分钟而不是毫秒，并且可能导致节点响应缓慢甚至断开与群集的连接。

**1. 使用swapoff禁止所有的交换**

通常Elasticsearch是在系统上运行的唯一服务，其内存使用量由JVM选项控制。无需启用交换功能。

在Linux系统上，可以通过运行以下命令暂时禁用交换：

```
sudo swapoff -a
```

要永久禁用它，需要编辑`/etc/fstab`文件并注释掉包含单词swap的所有行。


**2. 配置swappiness允许紧急情况使用内存交换**

在Linux系统上可用的**另一种选择是确保将sysctl值vm.swappiness设置为1。这可以减少内核的交换趋势，并且在正常情况下不应导致交换，同时仍然允许整个系统在紧急情况下进行交换**。vm.swappiness参数可以在机器使用内存、交互分区的比例进行调整，起到优化作用

 1. vm.swappiness的值在0-100之间，当为0表示最大限度只用物理内存，而后使用swap空间；当swappiness为100时表示最大限度使用swap空间，把内存中的数据及时搬运到swap空间中去

 2. 当内存使用到(100-vm.swappiness)%时，就会开始出现交换分区的使用了。

配置swappingess:

1. 查看当前设置的vm.swappiness值

```
sysctl -q vm.swappiness
或
cat /proc/sys/vm/swappiness
```

2. 临时调整，会在机器重启后恢复原先设置的值

```
sysctl vm.swappiness=10
```

3. 永久调整

```
# /etc/sysctl.conf
vm.swappiness=10
```
而后重载配置：
```
sysctl -p
```

**3. 配置bootstrap.memory_lock禁止ES内存交换**

在类Unix系统上使用mlockall或在Windows上使用VirtualLock尝试将进程地址空间锁定在RAM中，以防止任何Elasticsearch内存被换出。可以通过将以下行添加到config / elasticsearch.yml文件中来完成此操作：

```
bootstrap.memory_lock: true
```

注意: 如果mlockall尝试分配的内存超过可用内存，则可能导致JVM退出！

启动Elasticsearch之后，可以通过检查此请求的输出中的mlockall值来查看是否成功应用了此设置：
```
GET _nodes?filter_path=**.mlockall
```

如果看到mlockall为false，则表示mlockall请求已失败，将在日志中看到一行包含更多信息的行，内容为“无法锁定JVM内存”。内存锁定失败可以查看[系统配置-无法锁定JVM内存](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/setup-configuration-memory.html)

### 增加文件描述符数量

Elasticsearch在使用过程中会打开许多文件描述符，请确保将运行Elasticsearch的用户最大打开文件描述符的数量的限制提高到65536或更高。

下面增加文件描述符数量：

```
sudo ulimit -n 65535 // 更改打开最大文件数为65535
```

或者在/etc/security/limits.conf中将nofile设置为65535:

```
elasticsearch  -  nofile  65535
```

启动Elasticsearch之后，通过以下方式检查是否设置成功：

```
GET _nodes/stats/process?filter_path=**.max_file_descriptors
```

### 确保有足够的虚拟内存

Elasticsearch默认使用mmapfs目录存储其索引。默认的操作系统对mmap计数的限制可能太低，这可能会导致内存不足异常。


```
sysctl vm.max_map_count
sudo sysctl -w vm.max_map_count=262144
```

永久性配置：

```
# vi /etc/sysctl.conf
vm.max_map_count=262144
```

### 确保足够的线程

Elasticsearch对不同类型的操作使用许多线程池。需要确保Elasticsearch用户可以创建的线程数至少为4096。

可以通过在启动Elasticsearch之前执行`sudo ulimit -u 4096`，重启系统会失效

或者永久性更改

```
# cat /etc/security/limits.conf
elasticsearch - nproc  4096
```

### Elasticsearch配置

### 最少候选主节点配置

为了防止数据丢失，至关重要的是配置`discovery.zen.minimum_master_nodes`，该配置是为了使用每个候选主节点(master eligible node)都知道形成ES集群最少节点数量。最少候选节点节点数在分布式系统中称为`Quorum`（法定人数)。

设置`Quorum`是为了防止网络故障时候，ES群集会发生脑裂，这会造成数据丢失。为避免大脑分裂，应将`discovery.zen.minimum_master_nodes`设置候选主节点数的一半加1：

```
(master_eligible_nodes / 2) + 1
```

对于较小ES集群，可以选择3或者5个候选主节点。下表是分布式服务节点`Quorum`数量参考：

Servers	| Quorum Size	| Failure Tolerance
--- | --- | ---
1	| 1	 | 0
2	| 2	| 0
3	| 2	| 1
4	| 3	| 1
5	| 3	| 2
6	| 4	| 2
7	| 4	| 3

关于脑裂更多知识参见[Avoiding split brain with minimum_master_nodes](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/modules-node.html#split-brain)

### 设置合理堆大小

默认情况下，Elasticsearch的JVM使用最小和最大大小为1 GB的堆。生产换中需确保Elasticsearch有足够的可用堆。

Elasticsearch将通过Xms（最小堆大小）和Xmx（最大堆大小）设置分配jvm.options中指定的整个堆。

设置堆大小应该遵循以下原则：

1. 将最小堆大小（Xms）和最大堆大小（Xmx）设置一样大小
2. Xmx设置不应超过物理RAM的50％，以确保有足够的内核文件缓存来存储lucene的segment。
3. 请勿将Xmx设置为高于JVM用于压缩对象指针的临界值，即不要超过32G


可以通过在日志中查找如下一行来验证压缩对象指针是否处于限制范围内：
> heap size [1.9gb], compressed ordinary object pointers [true]


我们通过如下设置堆大小：

```
# vi /usr/share/elasticsearch/config
-Xms2g  // 最小堆大小为2g
-Xmx2g // 最大对大小为2g
```

或者通过环境变量设置：

```
ES_JAVA_OPTS="-Xms2g -Xmx2g" ./bin/elasticsearch 
```

### 禁止自动创建索引

当向一个不存在的索引中写入文档时，会自动创建索引。为了更好控制索引的创建，推荐在生产环境配置禁止自动创建索引

```bash
PUT /_cluster/settings
{
    "persistent": {
        "action.auto_create_index": "false" 
    }
}
```

对于日志类等基于时间序列的索引，可能需要允许自动创建索引，我们可以设置白名单

```bash
PUT /_cluster/settings
{
    "persistent": {
        "action.auto_create_index": "logstash-*,.kibana*" 
    }
}
```

### 禁止通过通配符或_all删除索引

为了安全，应该禁止通过通配符号或_all删除索引

```bash
PUT /_cluster/settings
{
  "persistent": {
    "action.destructive_requires_name": "true"
  }
}
```

### 防止监控日志索引占用过大空间

xpack支持ES和kibana的监控，默认保存15天的监控日志。若磁盘空间有限，可以考虑调整监控索引(.monitoring-es-*、 .monitoring-kibana-*等)保留天数

```bash
PUT /_cluster/settings
{
    "persistent": {
        "xpack.monitoring.history.duration":"3d"
    }
}
```

### 开启慢日志

开启慢日志的目的是捕获那些超过指定时间阈值的查询和索引请求，以便针对性优化。慢日志默认是不开启的。慢日志是shard-level的，分为搜索慢日志和索引慢日志。我们可以针对特定索引开启慢日志，也可针对整个集群设置慢日志，所有索引都会继承集群慢日志设置。

慢日志设置时候需要定义日志类型(search和indexing)，日志记录级别，以及时间阈值。

针对特定索引开启搜索慢日志：

```bash
/my_index/_settings
{
    "index.search.slowlog.threshold.query.warn": "10s",
    "index.search.slowlog.threshold.query.info": "5s",
    "index.search.slowlog.threshold.query.debug": "2s",
    "index.search.slowlog.threshold.query.trace": "500ms",
    "index.search.slowlog.threshold.fetch.warn": "1s",
    "index.search.slowlog.threshold.fetch.info": "800ms",
    "index.search.slowlog.threshold.fetch.debug": "500ms",
    "index.search.slowlog.threshold.fetch.trace": "200ms",
    "index.search.slowlog.level": "info" // 只记录info和info以上的慢日志
}
```
设置多个日志级别是为了方便更好grep定位。根据自己需求设置。

针对特定索引开启索引慢日志：

```bash
PUT /my_index/_settings
{
    "index.indexing.slowlog.threshold.index.warn": "10s",
    "index.indexing.slowlog.threshold.index.info": "5s",
    "index.indexing.slowlog.threshold.index.debug": "2s",
    "index.indexing.slowlog.threshold.index.trace": "500ms",
    "index.indexing.slowlog.level": "info",
    "index.indexing.slowlog.source": "1000" // 只记录前1000个字符
}
```

针对整个集群设置：

```bash
PUT /_cluster/settings
{
    "transient": {
        "logger.index.search.slowlog": "DEBUG",
        "logger.index.indexing.slowlog": "DEBUG"
    }
}
```

### 禁止自动创建mapping

默认情况下，ES会自动创建推断文档的field类型，并自动创建mapping，有时候设置字段类型并不是最合适的，我们需要禁止自动创建mapping。

```bash
PUT my_index
{
  "mappings": {
    "_doc": {
      "dynamic": false, // 禁止dynamic mapping
      "properties": {
        "user": { 
          "properties": {
            "name": {
              "type": "text"
            },
            "social_networks": { 
              "dynamic": true,
              "properties": {}
            }
          }
        }
      }
    }
  }
}
```

`dynamic`设置一共有3个值可选，默认是true，我们需要设置false或者strict即可。

值 | 功能
--- | ---
true | 自动侦测新字段，并加到mapping中。默认值
false | 新字段不会被索引，但会随着`_source`字段返回
strict | 若新字段没有添加到mapping中，则创建文档时候报错


### 参考资料

- [Important System Configuration](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/setup-configuration-memory.html)
- [Important Elasticsearch configuration](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/important-settings.html)
- [Slow log](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/index-modules-slowlog.html)
- [Dynamic Mapping](https://www.elastic.co/guide/en/elasticsearch/reference/current/dynamic-mapping.html)
