## Elasticsearch中的内存

ES是基于JVM实现的，内存分配分为堆内和堆外两部分。每部分的内存，可以用不同目的的缓存。

![](https://static.cyub.vip/images/202010/es_memory.jpg)

### 堆内存与堆外内存

一般情况下，Java中分配的非空对象都是由Java虚拟机的垃圾收集器管理的，称为**堆内内存（on-heap memory）**。虚拟机会定期对垃圾内存进行回收，在某些特定的时间点，它会进行一次彻底的回收（full gc）。彻底回收时，垃圾收集器会对所有分配的堆内内存进行完整的扫描，这意味着一个重要的事实——这样一次垃圾收集对Java应用造成的影响，跟堆的大小是成正比的。过大的堆会影响Java应用的性能。

Java虚拟机的堆以外的内存，即直接收操作系统管理的内存属于**堆外内存（off-heap memory）**，通过把内存对象分配在堆外内存中，可以保持一个较小的堆，可以减少垃圾回收对应用的影响。

<!--more-->

### ES堆内存

我们通过ES启动命名参数选项来设置堆内存大小：

```
./bin/elasticsearch -Xmx5g -Xms5g
```

注意事项：

1. 堆内存最大值(Xmx)应与对堆内存最小值应该一致，防止程序运行时候会改变堆内存大小，这个很耗系统资源

2. **堆内存最大不能超过32GB**。因为在Java中，所有对象都分配在堆上并由指针引用。32位的系统，堆内存大小最大为 4 GB。对于64位系统，可通过[内存指针压缩（compressed oops）](https://wikis.oracle.com/display/HotSpotInternals/CompressedOops)技术，依旧可以使用32位的指针来指向堆对象，这样可以大大节省CPU 内存带宽，提高操作效率。但当内存大小超过32G时候，对象指针就需要变大，操作效率就大大降低。


#### 节点查询缓存

[节点查询缓存(Node Query Cache)](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-cache.html)属于`node-level`缓存，能够被当前节点的所有shard所共享，用于缓存filter的查询结果。`Node Query Cache`采取LRU内存淘汰策略，当缓存满了，会evicted(驱逐，淘汰)最近最少使用的节点查询缓存。

节点查询缓存的配置重要参数有以下几个：

- **indices.queries.cache.size** 

    用来控制缓存的内存大小，默认是10%，属于节点级别配置。支持百分数，也支持大小精确值。该配置属于[静态配置](https://www.elastic.co/guide/en/elasticsearch/reference/current/settings.html#static-cluster-setting)，更改配置需要重启节点
- index.queries.cache.enabled
    
    用来控制具体索引是否启用缓存，默认是开启的。属于index级别配置。只用在索引创建时候或者关闭的索引上设置
    
- indices.queries.cache.all_segments

    用于控制是否在所有Segment上启用缓存，默认是false,即不会对文档数小于100000或者小于整个索引大小的3%的Segment进行缓存

#### 索引缓冲

当文档创建时候，会先保存在[索引缓冲(Indexing Buffer)](https://www.elastic.co/guide/en/elasticsearch/reference/current/indexing-buffer.html)中，然后每隔`index.refresh_interval`或者索引缓存满的时候进行refresh操作，将文档的段存在系统缓存中，此时文档才能搜索到。


索引缓存的配置重要参数有以下几个：

- **indices.memory.index_buffer_size**

    用于控制index buffer大小，属于节点级别配置。默认是10%，即允许分配到整个堆大小的10%。支持百分数，也支持大小精确值。
- indices.memory.min_index_buffer_size

    用于控制index buffer大小的最小值，当index_buffer_size为百分数时候，才生效。默认是`48mb`

- indices.memory.max_index_buffer_size

    用于控制index buffer大小的最大值，当index_buffer_size为百分数时候，才生效。默认是**unbounded**（无上限的)

#### 分片请求缓存

[分片请求缓存(Shard Request Cache)](https://www.elastic.co/guide/en/elasticsearch/reference/current/shard-request-cache.html)属于`shard-level`缓存。当进行索引搜索时候，每个相关的shard在本地执行搜索，并将其本地结果返回给协调节点(Coordinating Node)，协调节点将这些分片级别的结果合并为一个“全局”结果集。

**分片请求缓存只缓存size=0的搜索请求的结果，它不会缓存hits，但会缓存hits.total, aggregations, suggestions**。

分片请求缓存的配置重要参数如下：

- indices.requests.cache.size

    设置请求缓存大小，默认是1%。该配置是静态配置。

索引的请求缓存默认是开启的，该配置可以动态开启或关闭：

```bash
PUT /my-index/_settings
{ "index.requests.cache.enable": true }
```
索引请求缓存的key是根据请求的`JSON body`得来，当请求的`JSON body`改变之后，之前缓存的也会失效。另外对于频繁更新的index的，不建议使用该缓存。

我们可以通过以`_stat`API查看分片请求缓存大小

```
GET /_stats/request_cache?human // 查看每个索引的request cache大小

GET /_nodes/stats/indices/request_cache?human // 按节点查看request cache 大小
```

#### Fielddata Cache

对于Text类型的字段，如果要对其进行聚合和排序，则需要打开字段的`Fileddata`属性。当对该字段进行聚合，排序时候，ES会把Field Data中加载到内存中，构建成`Fielddata Cache`，该缓存属于`segment-level`级别的，整个segment生命周期内都存在。


Fielddata Cache的配置重要参数如下：
- indices.fielddata.cache.size
    
    用来控制索引的fileddata cache大小。默认是`unbounded`。支持百分数，也支持大小精确值。该参数是静态配置类型。
    
    大小默认是没有限制的原因是fielddata不是临时性的cache，它能够极大地提升性能，而且构建fielddata又比较耗时的操作，所以需要一直cache。如果没有足够的内存保存fielddata时，Elastisearch会不断地从磁盘加载数据到内存，并剔除掉旧的内存数据。剔除操作会造成严重的磁盘I/O，并且引发大量的GC，会严重影响Elastisearch的性能。
- indices.breaker.fielddata.limit

    用来设置[Fielddata断路器](https://www.elastic.co/guide/en/elasticsearch/reference/current/circuit-breaker.html#fielddata-circuit-breaker)限制大小，默认是JVM heap大小的40%。当加载的内存中fielddata数据超过该限制大小，会发生异常，目的为了防止发生JVM OOM。可以动态设置
- indices.breaker.fielddata.overhead

    用来设置fielddata过载值，默认值是1.03

我们可以通过以下API查看fielddata大小：

```
GET /_nodes/stats/indices/fielddata?human

GET /_cat/nodes?v&h=id,ip,port,v,master,name,heap.current,heap.percent,heap.max,ram.current,ram.percent,ram.max,fielddata.memory_size,fielddata.evictions,query_cache.memory_size,query_cache.evictions, request_cache.memory_size,request_cache.evictions,request_cache.hit_count,request_cache.miss_count

GET /_cat/fielddata?v
```

### ES堆外内存

在设置ES堆内存时候至少要预留50%物理内存，因为这部分内存主要用做ES堆外内存，**堆外内存主要用来来存储Lucene的段**

Elasticsearch是基于Lucene实现。Lucene的segments存储在单个文件中，这些文件都是不可变的，文件中包含用于搜索的倒排索引和用于聚合的doc values。为了提高性能，这些文件以系统内存(page cache)的形式常驻常驻内存空间。

我们可以通过`cat segments`查看索引的segment使用内存的情况：

```
GET /_cat/segments?v
```

### 缓存的清除

清除全部的缓存：

```bash
POST /_cache/clear
```

清除特定索引的缓存：

```bash
POST /my_index/_cache/clear
POST /my_index1,my_index2/_cache/clear
```

清除特定类型缓存：

通过设置`fielddata`,`query`,`request`参数为`true`来清除特定类型的缓存

```bash
POST /my-index/_cache/clear?fielddata=true  
POST /my-index/_cache/clear?query=true      
POST /my-index/_cache/clear?request=true   
```

### 参考资料

- [Nodes stats API](https://www.elastic.co/guide/en/elasticsearch/reference/current/cluster-nodes-stats.html)
- [Clear cache API](https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-clearcache.html)
- [Cat nodes API](https://www.elastic.co/guide/en/elasticsearch/reference/current/cat-nodes.html)
- [Configuring Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/settings.html#static-cluster-setting)