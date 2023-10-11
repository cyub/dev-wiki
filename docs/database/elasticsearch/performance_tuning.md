## Elasticsearch 性能调优

从linux参数调优、ES节点配置和ES使用技巧三个角度入手，介绍ES调优的基本方案。

当我们发现es使用还是非常慢，需要优先关注在以下这两类的运行情况：

- hot_threads
    [hot_threads](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/cluster-nodes-hot-threads.html)（GET /_nodes/hot_threads&interval=30），抓取30s的节点上占用资源的热线程，并通过排查占用资源最多的TOP线程来判断对应的资源消耗是否正常，一般情况下，bulk，search类的线程占用资源都可能是业务造成的，但是如果是merge线程占用了大量的资源，就应该考虑是不是创建index或者刷磁盘间隔太小，批量写入size太小造成的。
- pending_tasks
    [pending_tasks](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/cluster-pending.html)（GET /_cluster/pending_tasks），有一些任务只能由主节点去处理，比如创建一个新的 索引或者在集群中移动分片，由于一个集群中只能有一个主节点，所以只有这一master节点可以处理集群级别的元数据变动。在99.9999%的时间里，这不会有什么问题，元数据变动的队列基本上保持为零。在一些罕见的集群里，元数据变动的次数比主节点能处理的还快，这会导致等待中的操作会累积成队列。这个时候可以通过pending_tasks api分析当前什么操作阻塞了es的队列，比如，集群异常时，会有大量的shard在recovery，如果集群在大量创建新字段，会出现大量的put_mappings的操作，所以正常情况下，需要禁用动态mapping。


### Linux参数调优

#### 关闭交换分区

防止内存置换降低性能

> sed -i '/swap/s/^/#/' /etc/fstab swapoff -a

#### 磁盘挂载选项

- noatime：禁止记录访问时间戳，提高文件系统读写性能

- data=writeback： 不记录data journal，提高文件系统写入性能

- barrier=0：barrier保证journal先于data刷到磁盘，上面关闭了journal，这里的barrier也就没必要开启了

- nobh：关闭buffer_head，防止内核打断大块数据的IO操作

> mount -o noatime,data=writeback,barrier=0,nobh /dev/sda /es_data

#### 其他

```
// 修改系统资源限制，单用户可以打开的最大文件数量，可以设置为官方推荐的65536或更大些
echo "* - nofile 655360" >>/etc/security/limits.conf

// 单用户内存地址空间
echo "* - as unlimited" >>/etc/security/limits.conf

// 单用户线程数
echo "* - nproc 2056474" >>/etc/security/limits.conf

// 单用户文件大小
echo "* - fsize unlimited" >>/etc/security/limits.conf

// 单用户锁定内存
echo "* - memlock unlimited" >>/etc/security/limits.conf

// 单进程可以使用的最大map内存区域数量
echo "vm.max_map_count = 655300" >>/etc/sysctl.conf

// TCP全连接队列参数设置， 这样设置的目的是防止节点数较多（比如超过100）的ES集群中，节点异常重启时全连接队列在启动瞬间打满，造成节点hang住，整个集群响应迟滞的情况
echo "net.ipv4.tcp_abort_on_overflow = 1" >>/etc/sysctl.conf
echo "net.core.somaxconn = 2048" >>/etc/sysctl.conf

//  降低tcp alive time，防止无效链接占用链接数
echo 300 >/proc/sys/net/ipv4/tcp_keepalive_time
```

### ES节点配置

#### buffer和bulk队列长度

适当增大写入buffer和bulk队列长度，提高写入性能和稳定性

```
# cat conf/elasticsearch.yml

indices.memory.index_buffer_size: 15%
thread_pool.bulk.queue_size: 1024
```

#### 新建shard时扫描元数据

在规模比较大的集群中，可以防止新建shard时扫描所有shard的元数据，提升shard分配速度。

```
cat conf/elasticsearch.yml
cluster.routing.allocation.disk.include_relocations: false
```

#### jvm.options

-Xms和-Xmx设置为相同的值，推荐设置为机器内存的一半左右，剩余一半留给系统cache使用。

- jvm内存建议不要低于2G，否则有可能因为内存不足导致ES无法正常启动或OOM
- jvm建议不要超过32G，否则jvm会禁用内存对象指针压缩技术，造成内存浪费


#### 设置内存熔断参数

设置内存熔断参数，防止写入或查询压力过高导致OOM，具体数值可根据使用场景调整。

```
// cat conf/elasticsearch.yml
indices.breaker.total.limit: 30%
indices.breaker.request.limit: 6%
indices.breaker.fielddata.limit: 3%
```

#### query cache

调小查询使用的cache，避免cache占用过多的jvm内存，具体数值可根据使用场景调整。

```
# cat conf/elasticsearch.yml
indices.queries.cache.count: 500
indices.queries.cache.size: 5%
```

### ES使用技巧

ES底层使用Lucene存储数据，主要包括行存（StoreFiled）、fielddata、列存（DocValues）和倒排索引（InvertIndex）。大多数使用场景中，没有必要同时存储这四个部分。

当前用得最多的就是doc_values，列存储，对于不需要进行分词的字段，都可以开启doc_values来进行存储（且只保留keyword字段），节约内存，当然，开启doc_values会对查询性能有一定的影响，但是，这个性能损耗是比较小的，而且是值得的。

可以通过下面的参数来做适当调整：

#### StoreFiled

行存，其中占比最大的是_source字段，它控制doc原始数据的存储。在写入数据时，ES把doc原始数据的整个json结构体当做一个string，存储为source字段。查询时，可以通过source字段拿到当初写入时的整个json结构体。 所以，如果没有取出整个原始json结构体的需求，可以通过下面的命令，在mapping中关闭source字段或者只在source中存储部分字段，数据查询时仍可通过ES的docvaluefields获取所有字段的值。

**注意：**关闭source后， update, updatebyquery, reindex等接口将无法正常使用，所以有update等需求的index不能关闭source。

```
// 关闭 _source
PUT my_index 
{
    "mappings": {
        "my_type": {
            "_source": {
                "enabled": false
            }
        }
    }
}
// _source只存储部分字段，通过includes指定要存储的字段或者通过excludes滤除不需要的字段
PUT my_index
{
    "mappings": {
        "_doc": {
            "_source": {
                "includes": [
                    "*.count",
                    "meta.*"
                ],
                "excludes": [
                    "meta.description",
                    "meta.other.*"
                ]
            }
        }
    }
}
```

#### fielddata

构建和管理 100% 在内存中，常驻于 JVM 内存堆，所以可用于快速查询，但是这也意味着它本质上是不可扩展的，有很多边缘情况下要提防，如果对于字段没有分析需求，可以关闭fielddata

#### docvalues

控制列存。ES主要使用列存来支持sorting, aggregations和scripts功能，对于没有上述需求的字段，可以通过下面的命令关闭docvalues，降低存储成本。

```
PUT my_index
{
    "mappings": {
        "my_type": {
            "properties": {
                "session_id": {
                    "type": "keyword",
                    "doc_values": false
                }
            }
        }
    }
}
```

#### index

控制倒排索引。ES默认对于所有字段都开启了倒排索引，用于查询。对于没有查询需求的字段，可以通过下面的命令关闭倒排索引。

- all：ES的一个特殊的字段，ES把用户写入json的所有字段值拼接成一个字符串后，做分词，然后保存倒排索引，用于支持整个json的全文检索。这种需求适用的场景较少，可以通过下面的命令将all字段关闭，节约存储成本和cpu开销。（ES 6.0+以上的版本不再支持_all字段，不需要设置）
- [fieldnames](https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-field-names-field.html)：该字段用于exists查询，来确认某个doc里面有无一个字段存在。若没有这种需求，可以将其关闭

```
PUT my_index
{
    "mappings": {
        "my_type": {
            "properties": {
                "session_id": {
                    "type": "keyword",
                    "index": false
                }
            }
        }
    }
}
PUT my_index
{
    "mapping": {
        "my_type": {
            "_all": {
                "enabled": false
            }
        }
    }
}
PUT my_index
{
    "mapping": {
        "my_type": {
            "_field_names": {
                "enabled": false
            }
        }
    }
}
```

#### 开启最佳压缩

对于_source字段，可以通过下面的命令来把lucene适用的压缩算法替换成 DEFLATE，提高数据压缩率

```
PUT /my_index/_settings
{
    "index.codec": "best_compression"
}
```

#### bulk

写入数据时尽量使用下面的bulk接口批量写入，提高写入效率。每个bulk请求的doc数量设定区间推荐为1k~1w，具体可根据业务场景选取一个适当的数量。

#### 调整translog同步策略

为了保证不丢数据，translog的持久化策略是，对于每个 index、bulk、delete、update请求都做一次flush（刷新translog数据到磁盘上）。这种频繁的磁盘IO操作是严重影响写入性能的，如果可以接受一定概率的数据丢失（这种硬件故障的概率很小），可以通过下面的命令调整 translog 持久化策略为异步周期性执行，并适当调整translog的刷盘周期。

```
PUT my_index
{
    "settings": {
        "index": {
            "translog": {
                "sync_interval": "5s",
                "durability": "async"
            }
        }
    }
}
```

#### 调整refresh_interval
写入Lucene的数据，并不是实时可搜索的，ES必须通过refresh的过程把内存中的数据转换成Lucene的完整segment后，才可以被搜索。

要不要秒级响应？最快1s（index.refresh_interval【默认为一秒】）写入的数据可以被查询到，势必会产生大量的segment，检索性能会受到影响。所以，非实时的场景可以调大，设置为30s，降低系统开销。

#### merge并发控制

ES的一个index由多个shard组成，而一个shard其实就是一个Lucene的index，它又由多个segment组成，且Lucene会不断地把一些小的segment合并成一个大的segment，这个过程被称为段merge。执行索引操作时，ES会先生成小的segment，ES有离线的逻辑对小的segment进行合并，优化查询性能。但是合并过程中会消耗较多磁盘IO，会影响查询性能。

index.merge.scheduler.max_thread_count控制并发的merge线程数，如果存储是并发性能较好的SSD，可以用系统默认的max(1, min(4, availableProcessors / 2))，当节点配置的cpu核数较高时，merge占用的资源可能会偏高，影响集群的性能，普通磁盘的话设为1。可以通过下面的命令调整某个index的merge过程的并发度：

```
PUT /my_index/_settings
{
    "index.merge.scheduler.max_thread_count": 2
}
```

#### 不要指定_id

当用户显示指定id写入数据时，ES会先发起查询来确定index中是否已经有相同id的doc存在，若有则先删除原有doc再写入新doc。这样每次写入时，ES都会耗费一定的资源做查询。如果用户写入数据时不指定doc，ES则通过内部算法产生一个随机的id，并且保证id的唯一性，这样就可以跳过前面查询id的步骤，提高写入效率。所以，在不需要通过id字段去重、update的使用场景中，写入不指定id可以提升写入速率。基础架构部数据库团队的测试结果显示，无id的数据写入性能可能比有_id的高出近一倍，实际损耗和具体测试场景相关。

#### 使用routing

对于数据量较大的index，一般会配置多个shard来分摊压力。这种场景下，一个查询会同时搜索所有的shard，然后再将各个shard的结果合并后，返回给用户。对于高并发的小查询场景，每个分片通常仅抓取极少量数据，此时查询过程中的调度开销远大于实际读取数据的开销，且查询速度取决于最慢的一个分片。开启routing功能后，ES会将routing相同的数据写入到同一个分片中（也可以是多个，由index.routingpartitionsize参数控制）。如果查询时指定routing，那么ES只会查询routing指向的那个分片，可显著降低调度开销，提升查询效率。

```
// 写入
PUT my_index/my_type/1?routing=user1
{
    "title": "This is a document"
}
//查询
GET my_index/_search?routing=user1,user2 
{
    "query": {
        "match": {
            "title": "document"
        }
    }
}
```

#### text or keyword

为string类型的字段选取合适的存储方式，text或者keywork类型。

#### 使用query-bool-filter组合取代普通query

默认情况下，ES通过一定的算法计算返回的每条数据与查询语句的相关度，并通过score字段来表征。但对于非全文索引的使用场景，用户并不care查询结果与查询条件的相关度，只是想精确的查找目标数据。此时，可以通过query-bool-filter组合来让ES不计算score，并且尽可能的缓存filter的结果集，供后续包含相同filter的查询使用，提高查询效率。

```
// 普通查询
POST my_index/_search
{
    "query": {
        "term": {
            "user": "Kimchy"
        }
    }
}
// query-bool-filter 加速查询
POST my_index/_search
{
    "query": {
        "bool": {
            "filter": {
                "term": {
                    "user": "Kimchy"
                }
            }
        }
    }
}
```

#### index按日期滚动存储

写入ES的数据最好通过某种方式做分割，存入不同的index。常见的做法是将数据按模块/功能分类，写入不同的index，然后按照时间去滚动生成index。这样做的好处是各种数据分开管理不会混淆，也易于提高查询效率。同时index按时间滚动，数据过期时删除整个index，要比一条条删除数据或deletebyquery效率高很多，因为删除整个index是直接删除底层文件，而deletebyquery是查询-标记-删除。

```
// module_a
PUT module_a@2018_01_01
{
   "settings" : {
       "index" : {
           "number_of_shards" : 3,
           "number_of_replicas" : 2
       }
   }
}
PUT module_a@2018_01_02
{
   "settings" : {
       "index" : {
           "number_of_shards" : 3,
           "number_of_replicas" : 2
       }
   }
}
GET module_a@*/_search

// module_b
PUT module_b@2018_01_01
{
   "settings" : {
       "index" : {
           "number_of_shards" : 3,
           "number_of_replicas" : 2
       }
   }
}
PUT module_b@2018_01_02
{
   "settings" : {
       "index" : {
           "number_of_shards" : 3,
           "number_of_replicas" : 2
       }
   }
}
GET module_b@*/_search
```

#### 分片数和副本数按需控制

对于每个index的shard数量，可以根据数据总量、写入压力、节点数量等综合考量后设定，然后根据数据增长状态定期检测下shard数量是否合理。[多少合适？](https://blog.csdn.net/alex_xfboy/article/details/85332383#2.%C2%A0%E5%88%86%E7%89%87%E5%8F%8A%E5%89%AF%E6%9C%AC)

#### Segment Memory优化

ES底层采用Lucene做存储，而Lucene的一个index又由若干segment组成，每个segment都会建立自己的倒排索引用于数据查询。Lucene为了加速查询，为每个segment的倒排做了一层前缀索引，这个索引在Lucene4.0以后采用的数据结构是FST (Finite State Transducer)。Lucene加载segment的时候将其全量装载到内存中，加快查询速度。这部分内存被称为SegmentMemory， 常驻内存，占用heap，无法被GC。前面提到，为利用JVM的对象指针压缩技术来节约内存，通常建议JVM内存分配不要超过32G。当集群的数据量过大时，SegmentMemory会吃掉大量的堆内存，而JVM内存空间又有限，此时就需要想办法降低SegmentMemory的使用量了，常用方法有下面几个：

- 定期删除不使用的index
- 对于不常访问的index，可以通过close接口将其关闭，用到时再打开
- 通过force_merge接口强制合并segment，降低segment数量

#### 禁止动态mapping

动态mapping的坏处：

- 造成集群元数据一直变更，导致集群不稳定
- 可能造成数据类型与实际类型不一致
- 对于一些异常字段或者是扫描类的字段，也会频繁的修改mapping，导致业务不可控

### 参考资料

- [Elasticsearch 性能调优](https://blog.csdn.net/alex_xfboy/article/details/87938810)
- [Elasticsearch高级调优方法论之——根治慢查询！](https://blog.csdn.net/laoyang360/article/details/100070285)
- [为什么Elasticsearch查询变得这么慢了？](https://blog.csdn.net/laoyang360/article/details/83048087)
- [提升集群写性能](https://learnku.com/articles/40845)
- [elasticsearch写入优化记录,从3000到8000/s](https://blog.csdn.net/wmj2004/article/details/80804411)
