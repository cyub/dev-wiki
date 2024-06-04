# mysql

## mysql存储引擎Myisam和innodb区别？

![](https://a-tour-of-golang.cyub.vip/_images/myisam_innodb.png)

1. InnoDB支持事务，MyISAM不支持

2. InnoDB支持外键，而MyISAM不支持

3. InoDB支持行级别锁，有更高的并发性，而MyISAM只支持表级别锁

3. InnoDB是聚集索引，数据文件是和索引绑在一起的，必须要有主键，通过主键索引效率很高

## mysql是ACID是如何保证的？

mysql事务特征有：

- 原子性(Atomicity)： 事务是最小的执行单位，不允许分割。事务的原子性确保动作要么全部完成，要么完全不起作用；

- 一致性(Consistency)： 执行事务前后，数据保持一致；

- 隔离性(Isolation)： 并发访问数据库时，一个用户的事务不被其他事务所干扰，各并发事务之间数据库是独立的；

- 持久性(Durability): 一个事务被提交之后。它对数据库中数据的改变是持久的，即使数据库 发生故障也不应该对其有任何影响。

保证措施：

- A 原子性由undo log日志保证，它记录了需要回滚的日志信息，事务回滚时撤销已经执行成功的sql
- C 一致性一般由代码层面来保证
- I 隔离性由MVCC来保证
- D 持久性由内存+redo log来保证，mysql修改数据同时在内存和redo log记录这次操作，事务提交的时候通过redo log刷盘，宕机的时候可以从redo log恢复。

## mysql事务隔离级别有哪些？

mysql支持四种隔离级别，默认是可重复读的 (REPEATABLE READ)。

隔离级别 | 脏读 | 不可重复读取 | 幻影数据行
--- | --- | --- | ---
READ UNCOMMITTED(RU) - 读未提交 |	X |	X |	X
READ COMMITTED(RC) - 读已提交| √	| X |	X
REPEATABLE READ(RR) - 可重复读	| √ |	√ |	X
SERIALIZABLE(SZ) - 串行化 |	√ |	√	| √

不可重复读与幻读的区别是？

1. 不可重复读的重点是修改:同样的条件, 你读取过的数据, 再次读取出来发现值不一样了，其只需要锁住满足条件的记录
2. 幻读的重点在于新增或者删除：同样的条件, 第1次和第2次读出来的记录数不一样，要锁住满足条件及其相近的记录

## mysql在可重复读模式下，如何解决不可重复读的问题？

mvcc+undo log解决了快照读可能会导致的不可重复读的问题。Mysql默认隔离级别是RR（可重复读），是通过“行锁+MVCC”来实现的，正常读时不加锁，写时加锁，MVCC的实现依赖于：三个隐藏字段，Read View、Undo log 来实现。

MVCC的目的就是多版本并发控制，在数据库中的实现，就是为了解决读写冲突，它的实现原理主要是依赖记录中的 3个隐式字段，undo log ，Read View 来实现的。
InnoDB MVCC的实现基于undo log，通过回滚指针来构建需要的版本记录。通过ReadView来判断哪些版本的数据可见。同时Purge线程是通过ReadView来清理旧版本数据。

## mysql的当前读和快照读是什么回事？

### 快照读

MVCC就是为了实现读-写冲突不加锁，而这个读指的就是快照读, 而非当前读，当前读实际上是一种加锁的操作，是悲观锁的实现。这个快照读的实现方式就是多版本并发控制MVCC。

快照读（snapshot read）能看到别的事务生成快照前提交的数据，而不能看到别的事务生成快照后提交的数据或者未提交的数据。快照读是repeatable-read 和 read-committed 级别下，默认的查询模式，好处是：读不加锁，读写不冲突，这个对于 MySQL 并发访问提升很大。

使用快照读的场景：

- 单纯的select操作，不包括上述 select … lock in share mode、select … for update

- Read Committed隔离级别下快照读：每次select都生成一个快照读

- Read Repeatable隔离级别下快照读：开启事务后第一个select语句才是快照读的地方，而不是一开启事务就快照读

### 当前读

当前读读取的是最新版本, 并且对读取的记录加锁，保证其他事务不会再并发的修改这条记录，避免出现安全问题。

使用当前读的场景：

- select…lock in share mode (共享读锁)

- select…for update

- update

- delete

- insert

当前读的实现方式：next-key锁(行记录锁+Gap间隙锁)

快照读和当前读实验：

![](https://static.cyub.vip/images/202107/mysql-snapshot-read.jpg)

### MVCC

![](https://static.cyub.vip/images/202107/mvcc_version.png)

未完成事务，也称为活跃事务。

- m_ids: 在生成ReadView时，当前活跃的-读写事务的事务id列表，包含当前事务版本
- min_trx_id: m_ids的最小值
- max_trx_id: m_ids的最大值+1，即下一个要生成的事务id
- creator_trx_id: 生成该事务的事务id

版本链中的当前版本是否可以被当前事务可见的要根据这四个属性按照以下几种情况来判断

- 当 trx_id = creator_trx_id 时:当前事务可以看见自己所修改的数据， 可见，
- 当 trx_id < min_trx_id 时 : 生成此数据的事务已经在生成readView前提交了， 可见
- 当 trx_id >= max_trx_id 时 :表明生成该数据的事务是在生成ReadView后才开启的， 不可见
- 当 min_trx_id <= trx_id < max_trx_id 时
    - trx_id 在 m_ids 列表里面 ：生成ReadView时，活跃事务还未提交，不可见
    - trx_id 不在 m_ids 列表里面 ：事务在生成readView前已经提交了，可见。(RC隔离级别会出现这种情况)


## innodb三种行锁算法

InnoDB有三种行锁的算法：

1. Record Lock：单个行记录上的锁。

2. Gap Lock：间隙锁，锁定一个范围，但不包括记录本身。GAP锁的目的，是为了防止同一事务的两次当前读，出现幻读的情况。

3. Next-Key Lock：1+2，锁定一个范围，并且锁定记录本身。对于行的查询，都是采用该方法，主要目的是解决幻读的问题。

## truncate,delete,drop区别？

- truncate 会删除所有数据
- delete 可以删除部分数据，会触发触发器
- drop会删除整个表和数据


## mysql索引分类

### 从物理存储角度

1. 聚簇索引

InnoDB中主键索引是聚集索引，索引跟数据在一起的。其他索引是非聚集索引，索引指向的是主键索引。为MyISAM存储引擎数据文件和索引文件是分离的，不存在聚集索引的概念。

2. 非聚簇索引

### 从数据结构角度

1. B+树索引

2. hash索引

    基于哈希表实现，只有全值匹配才有效

3. 全文索引

    查找的是文本中的关键词，而不是直接比较索引中的值，类似于搜索引擎做的事情。

### 从逻辑角度

1. 唯一索引，唯一索引也是一种约束。唯一索引的属性列不能出现重复的数据，但是**允许数据为NULL**，一张表允许创建多个唯一索引。UNIQUE ( column )

2. 主键索引，数据表的主键列使用的就是主键索引PRIMARY KEY ( column)

3. 联合索引，指多个字段上创建的索引 INDEX index_name ( column1, ... )，使用时最左匹配原则

4. 普通 /单列索引，普通索引的唯一作用就是为了快速查询数据，一张表允许创建多个普通索引，并允许数据重复和NULL。INDEX index_name ( column )。

5. 全文索引，查找的是文本中的关键词，而不是直接比较索引中的值，类似于搜索引擎做的事情。FULLTEXT ( column)

资料：https://juejin.cn/post/6907966385394515975

## mysql为什么使用b+树？

B+树是一个平衡的多叉树，B+树中的B不是代表二叉（binary），而是代表平衡（balance）。

B+树和B树区别：


1. B +树中的非叶子节点不存储数据，并且存储在叶节点中的所有数据使得查询时间复杂度固定为log n。

2. B树查询时间的复杂度不是固定的，它与键在树中的位置有关，最好是O（1）。


3. 由于B+树的叶子节点是通过双向链表链接的，所以支持范围查询，且效率比B树高


4. B树每个节点的键和数据是一起的

## 哈希索引的优势与劣势？

优点：

1. 等值查询，哈希索引具有绝对优势，时间复杂度为O(1)

缺点：

1. 不支持范围查询

2. 不支持索引完成排序

3. 不支持联合索引的最左前缀匹配规则

## 为什么uuid不适合做innodb主键？

## mysql调优几种方式
1. 打开慢查询日志，查看慢查询
2. explain看一下执行计划，查看①key字段是否使用到索引，使用到什么索引。②type字段是否为ALL全表扫描。③row字段扫描的行数是否过大，估计值。MySQL数据单位都是页，使用采样统计方法。④extra字段是否需要额外排序，就是不能通过索引顺序达到排序效果；是否需要使用临时表等。⑤如果是组合索引的话通过key_len字段判断是否被完全使用。
3. 使用覆盖索引。
4. 注意最左前缀原则
5. 使用前缀索引。当要给字符串加索引时，可以使用前缀索引，节省资源占用。如果前缀区分度不高可以倒序存储或者是存储hash。
6. 索引下推
7. 注意隐式类型转换，防止索引实现
8. 区分度不大的字段避免使用索引，比如性别字段

## mysql语句性能评测？

使用explain分析语句执行，主要看select_type、type、key、possiable keys、extra列。

### 查询类型 - select_type

- SIMPLE : 简单的select查询,查询中不包含子查询或者UNION

- PRIMARY: 查询中若包含复杂的子查询,最外层的查询则标记为PRIMARY

- SUBQUERY : 在SELECT或者WHERE列表中包含子查询

- DERIVED : 在from列表中包含子查询被标记为DRIVED衍生,MYSQL会递归执行这些子查询,把结果放到临时表中

- UNION: 若第二个SELECT出现在union之后,则被标记为UNION, 若union包含在from子句的子查询中,外层select被标记为:derived

- UNION RESULT: 从union表获取结果的select

### 连接类型 - type

有如下几种取值，性能从好到坏排序 如下：

- const
    
    针对主键或唯一索引的等值查询扫描, 最多只返回一行数据. const 查询速度非常快, 因为它仅仅读取一次即可

- ref
    
    当满足索引的**最左前缀规则**，或者索引不是主键也不是唯一索引时才会发生。如果使用的索引只会匹配到少量的行，性能也是不错的

- range

    范围扫描，表示检索了指定范围的行，主要用于**有限制的索引扫描**。比较常见的范围扫描是带有BETWEEN子句或WHERE子句里有>、>=、<、<=、IS NULL、<=>、BETWEEN、LIKE、IN()等操作符。

- index

    **全索引扫描**，和ALL类似，只不过index是全盘扫描了索引的数据。当查询仅使用索引中的一部分列时，可使用此类型。有两种场景会触发：
    如果索引是查询的覆盖索引，并且索引查询的数据就可以满足查询中所需的所有数据，则只扫描索引树。此时，explain的Extra 列的结果是Using index。index通常比ALL快，因为索引的大小通常小于表数据。

- ALL

    **全表扫描**，性能最差


### key

表示MySQL实际选择的索引

### possiable keys

MYSQL可能用到的key

### rows

MySQL估算会扫描的行数，数值越小越好。

## mysql主从复制流程？

![](https://static.cyub.vip/images/202107/mysql_bindump.png)

mysql slave节点连接master节点时，master节点会新建一个binlog dump线程，当master数据有更新时写入到binlog，dump线程通知slave的io线程接收后写入到本地的relaylog，然后通过sql线程重放

## mysql日志类型

mysql日志主要包括错误日志、查询日志、慢查询日志、事务日志、二进制日志几大类。

### binlog

binlog 用于记录数据库执行的写入性操作(不包括查询)信息，以二进制的形式保存在磁盘中。binlog 的主要使用场景有两个，分别是 主从复制 和 数据恢复。

- 主从复制 ：在 Master 端开启 binlog ，然后将 binlog发送到各个 Slave 端， Slave 端重放 binlog 从而达到主从数据一致。

- 数据恢复 ：通过使用 mysqlbinlog 工具来恢复数据。

### redo log

当有一条记录要更新时，InnoDB先记录日志再更新内存，然后在比较空闲的时候将操作更新到磁盘，有了redolog即使MySQL崩溃也不会丢失数据，这个能力称为crash-safe。redo log是事务持久性的保证。

### Undo log

undo log用于回滚操作，保证事务的原子性。

### slow log

slow log用来记录慢查询

## 查询语句不同元素（where、jion、limit、group by、having等等）执行先后顺序？

where在聚合前先筛选记录，也就是说作用在group by和having之前。而 having子句在聚合后对组记录进行筛选。

## Innodb为什么一定需要一个主键，且必须自增列作为主键？

如果我们定义了主键(PRIMARY KEY)，那么InnoDB会选择主键作为聚集索引。如果没有显式定义主键，则InnoDB会选择第一个不包含有NULL值的唯一索引作为主键索引。如果也没有这样的唯一索引，则InnoDB会选择内置6字节长的ROWID作为隐含的聚集索引(ROWID随着行记录的写入而主键递增，这个ROWID不像ORACLE的ROWID那样可引用，是隐含的)。

总之Innodb一定需要一个主键。

1. 这是因为数据记录本身被存于主索引（一颗B+Tree）的叶子节点上，这就要求同一个叶子节点内（大小为一个内存页或磁盘页）的各条数据记录按主键顺序存放
2. 如果表使用自增主键，那么每次插入新的记录，记录就会顺序添加到当前索引节点的后续位置，当一页写满，就会自动开辟一个新的页(这样的页称为叶子页)
3. 如果使用非自增主键（如果身份证号或学号等），由于每次插入主键的值近似于随机，因此每次新记录都要被插到现有索引页得中间某个位置

## 在MVCC并发控制中，读操作可以分成哪两类?

**快照读 (snapshot read)**：读取的是记录的可见版本 (有可能是历史版本)，不用加锁（共享读锁s锁也不加，所以不会阻塞其他事务的写）。

**当前读 (current read)**：读取的是记录的最新版本，并且，当前读返回的记录，都会加上锁，保证其他事务不会再并发修改这条记录。

## Mysql中DATATIME和TIMESTAP的区别？

datetime、timestamp精确度都是秒，datetime与时区无关，存储的范围广(1001-9999)，占空间8个字节，timestamp与时区有关，查询时候会转换成相应时区显示，存储的范围小(1970-2038)，占用空间4个字节。

## MySQL是如何解决幻读的？

- 事务隔离级别设置为SERIALIZABLE 串行化
- MVCC + Next-Key Lock

    Next-Key Lock(临键锁) 是Gap Lock（间隙锁）和Record Lock（记录锁，属于行锁）的结合版，都属于Innodb的锁机制。 比如：select * from tb where id>100 for update：

    1. 主键索引 id 会给 id=100 的记录加上 record行锁
    2. 索引 id 上会加上 gap 锁，锁住 id(100,+无穷大）这个范围，其他事务对  id>100 范围的记录读和写操作都将被阻塞。插入 id=1000的记录时候会命中索引上加的锁会报出事务异常；

    3. Next-Key Lock会确定一段范围，然后对这个范围加锁，保证A在where的条件下读到的数据是一致的，因为在where这个范围其他事务根本插不了也删不了数据，都被Next-Key Lock锁堵在一边阻塞掉了。

> 记录锁是行级别的锁（row-level locks），当InnoDB 对索引进行搜索或扫描时，会在索引对应的记录上设置共享或排他的记录锁。


## Mysql什么时候会取得gap lock或nextkey lock?

- 只在REPEATABLE READ或以上的隔离级别下的特定操作才会有可能取得gap lock或nextkey lock
- locking reads（SELECT with FOR UPDATE or LOCK IN SHARE MODE），UPDATE和DELETE时，除了对唯一索引的唯一搜索外都会获取gap锁或next-key锁。即锁住其扫描的范围。

    For locking reads (SELECT with FOR UPDATE or LOCK IN SHARE MODE), UPDATE, and DELETE statements, 
    locking depends on whether the statement uses a unique index with a unique search condition, 
    or a range-type search condition. For a unique index with a unique search condition, 
    InnoDB locks only the index record found, not the gap before it. For other search conditions, 
    InnoDB locks the index range scanned, using gap locks or next-key locks to block insertions 
    by other sessions into the gaps covered by the range.

    http://dev.mysql.com/doc/refman/5.7/en/innodb-transaction-isolation-levels.html

## Mysql为什么要进行分库分表？

- 数据量

    MySQL单库数据量在5000万以内性能比较好，超过阈值后性能会随着数据量的增大而变弱。MySQL单表的数据量是500w-1000w之间性能比较好，超过1000w性能也会下降。

- 磁盘

    因为单个服务的磁盘空间是有限制的，如果并发压力下，所有的请求都访问同一个节点，肯定会对磁盘IO造成非常大的影响。

- 数据库连接

    数据库连接是非常稀少的资源，如果一个库里既有用户、商品、订单相关的数据，当海量用户同时操作时，数据库连接就很可能成为瓶颈。

## Mysql什么时候使用分区？

- 查询速度慢，数据量大
- 对数据的操作往往只涉及一部分数据，而不是所有的数据


## Mysql分区类型有哪些？

Mysql分区后的一个优点是：涉及到 SUM()/COUNT() 等聚合函数时，可以并行进行。

MySQL支持范围分区（RANGE），列表分区（LIST），哈希分区（HASH）以及KEY分区四种。

分区字段不能为NULL，要不然怎么确定分区范围，所以尽量NOT NULL。

### 范围分区

基于属于一个给定连续区间的列值，把多行分配给分区。这些区间要连续且不能相互重叠，使用VALUES LESS THAN操作符来进行定义。

```sql
CREATE TABLE employees (
    id INT NOT NULL,
    fname VARCHAR(30),
    lname VARCHAR(30),
    hired DATE NOT NULL DEFAULT '1970-01-01',
    separated DATE NOT NULL DEFAULT '9999-12-31',
    job_code INT NOT NULL,
    store_id INT NOT NULL
)

partition BY RANGE (store_id) (
    partition p0 VALUES LESS THAN (6),
    partition p1 VALUES LESS THAN (11),
    partition p2 VALUES LESS THAN (16),
    partition p3 VALUES LESS THAN (21),
    PARTITION p4 VALUES LESS THAN MAXVALUE # MAXVALUE是最大值，防止store_id大于21时候，找不到分区写入失败
);
```

### LIST分区

类似于按RANGE分区，区别在于LIST分区是基于列值匹配一个离散值集合中的某个值来进行选择.

假定有20个音像店，分布在4个有经销权的地区，如下表所示：


地区 | 商店ID 号
--- | ---
北区 | 3, 5, 6, 9, 17
东区 | 1, 2, 10, 11, 19, 20
西区 | 4, 12, 13, 14, 18
中心区 | 7, 8, 15, 16

要按照属于同一个地区商店的行保存在同一个分区中的方式来分割表，可以使用下面的“CREATE TABLE”语句：

```sql
CREATE TABLE employees (
    id INT NOT NULL,
    fname VARCHAR(30),
    lname VARCHAR(30),
    hired DATE NOT NULL DEFAULT '1970-01-01',
    separated DATE NOT NULL DEFAULT '9999-12-31',
    job_code INT,
    store_id INT
)

PARTITION BY LIST(store_id)
    PARTITION pNorth VALUES IN (3,5,6,9,17),
    PARTITION pEast VALUES IN (1,2,10,11,19,20),
    PARTITION pWest VALUES IN (4,12,13,14,18),
    PARTITION pCentral VALUES IN (7,8,15,16)
);
```

需要注意的是如果试图插入列值（或分区表达式的返回值）不在分区值列表中的一行时，那么“INSERT”查询将失败并报错。

### HASH分区

基于用户定义的表达式的返回值来进行选择的分区，该表达式使用将要插入到表中的这些行的列值进行计算。

```sql
CREATE TABLE employees (
    id INT NOT NULL,
    fname VARCHAR(30),
    lname VARCHAR(30),
    hired DATE NOT NULL DEFAULT '1970-01-01',
    separated DATE NOT NULL DEFAULT '9999-12-31',
    job_code INT,
    store_id INT
)
PARTITION BY HASH(store_id)
PARTITIONS 4; # 一定要指定分区数
```

Hash分区的字段必须是整数类型，也可以基于用户定义的表达式的返回值进行分布区，但返回值必须是整数类型，比如：partition by hash (YEAR(b))。

### KEY分区

KEY分区跟HASH分区类似，分区字段可以是除text和BLOB外的所有类型，比如varchar类型。

## Mysql分库分表中间件有哪些？

分库分表中间件全部可以归结为两大类型：

- CLIENT模式

    阿里的TDDL，开源社区的sharding-jdbc

    没有中间层，性能开销低，维护和升级麻烦

- PROXY模式

    MyCat、DBProxy

    维护和升级相对简单些，支持集中式监控，缺点是有中间层，有成本开销，中间层必须高可用


## Mysql小表驱动大表优化技巧？

### Join

比如：user表10000条数据，class表20条数据

> select * from user u left join class c u.userid=c.userid

这样则需要用user表循环10000次才能查询出来，而如果用class表驱动user表则只需要循环20次就能查询出来

但是下面使用小结果集驱动大结果集，结果会更好：

> select * from class c left join user u c.userid=u.userid


### exist 还是 in

> select A.name from A where A.id in(select B.id from B)

表B驱动A

> select A.name from A where exists(select 1 from B where A.id = B.id)

表A驱动B


## 索引名字规则

```sql
idx(a, b, c)  HIT  where a = x and b = x
idx(a, b, c)  HIT  where a > x
idx(a, b, c)  Not HIT  where b > x
idx(a, b, c)  Not HIT  where a > x and b = x
idx(a, b, c)  Not HIT  where a = x and c = x

idx(a, b, c)  HIT  where a = x order by b
idx(a, b, c)  HIT  where a > x order by a
idx(a, b, c)  HIT  where a = x and b > x order by a
idx(a, b, c)  Not HIT  where a > x order by b
idx(a, b, c)  HIT  where a = x group by a, b
idx(a, b, c)  Not HIT  where a = x group by b
```

mysql建立多列索引（联合索引）有最左前缀的原则，即最左优先，如：

- 如果有一个2列的索引(col1,col2)，则已经对(col1)、(col1,col2)上建立了索引；
- 如果有一个3列索引(col1,col2,col3)，则已经对(col1)、(col1,col2)、(col1,col2,col3)上建立了索引；


最左前缀索引：

mysql会一直向右匹配直到遇到范围查询(>、<、between、like)就停止匹配，比如a = 1 and b = 2 and c > 3 and d = 4 如果建立(a,b,c,d)顺序的索引，d是用不到索引的，如果建立(a,b,d,c)的索引则都可以用到，a,b,d的顺序可以任意调整。

如where a>10 order by b ,索引a_b 无法排序
=和in可以乱序，比如a = 1 and b = 2 and c = 3 建立(a,b,c)索引可以任意顺序，mysql的查询优化器会帮你优化成索引可以识别的形式

b+ 树的数据项是复合的数据结构，比如 (name,age,sex) 的时候，b+ 树是按照从左到右的顺序来建立搜索树的，比如当 (张三,20,F) 这样的数据来检索的时候，b+ 树会优先比较 name 来确定下一步的所搜方向，如果 name 相同再依次比较 age 和 sex，最后得到检索的数据；但当 (20,F) 这样的没有 name 的数据来的时候，b+ 树就不知道第一步该查哪个节点，因为建立搜索树的时候 name 就是第一个比较因子，必须要先根据 name 来搜索才能知道下一步去哪里查询

## select xx for update where id = x操作会加写锁吗？

属于当前读，可能是行记录锁，也有可能是间隙锁。但都是加的写锁。写锁，意味着对其他客户端读写都会加锁，需要注意的是，并不是所有的读会加锁，它只对于其他客户端的当前读(select * for update, update, delete等）会加锁，普通的select不加锁的。

![](https://static.cyub.vip/images/202107/mysql-for-update.jpg)


## mysql中悲观锁、乐观锁、共享锁、排他锁有什么区别？

![](https://static.cyub.vip/images/202107/mysql-lock.jpg)

## 更多资料

- [MySQL记录锁、间隙锁、临键锁（Next-Key Locks）详解](https://blog.csdn.net/yzx3105/article/details/129675468)