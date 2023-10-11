
# HTTP

## 什么是HTTP协议？

超文本传输协议(HTTP)是一种通信协议，它允许将超文本标记语言(HTML)文档从Web服务器传送到客户端的浏览器。目前广泛使用的是HTTP/1.1 版本。

## HTTP请求消息和响应消息格式是？

### 请求消息

Request 消息分为3部分，第一部分叫Request line, 第二部分叫Request header, 第三部分是body. header和body之间有个空行， 结构如下图

![](https://a-tour-of-golang.cyub.vip/_images/request_msg.png)

### 响应消息

第一部分叫Response line, 第二部分叫Response header，第三部分是body. header字段之间要有空行（\r\n)，header和body之间也有个空行, 结构如下图:

![](https://a-tour-of-golang.cyub.vip/_images/response_msg.png)

## HTTP Cache流程是怎么样的？

![](https://a-tour-of-golang.cyub.vip/_images/http_cache.png)

## HTTP Cache有哪些重要的头？

#### Cache-Control

选项值有：

- Public ：所有内容都将被缓存，在响应头中设置
- Private ：内容只缓存到私有服务器中，在响应头中设置
- no-cache ：**不是不缓存，而是缓存需要校验**。
- no-store ：所有内容都不会被缓存到缓存或Internet临时文件中，在响应头中设置
must-revalidation/proxy-revalidation ：如果缓存的内容失效，请求必须发送到服务器/代理以进行重新验证，在请求头中设置
- max-age=xxx ：缓存的内容将在xxx秒后失效，这个选项只在HTTP1.1中可用，和Last-Modified一起使用时优先级较高，在响应头中设置

#### Expires

它通常的使用格式是Expires:Fri ,24 Dec 2027 04:24:07 GMT，后面跟的是日期和时间，超过这个时间后，缓存的内容将失效，浏览器在发出请求之前会先检查这个页面的这个字段，查看页面是否已经过期，过期了就重新向服务器发起请求

#### Last-Modified / If-Modified-Since

它一般用于表示一个服务器上的资源最后的修改时间，资源可以是静态或动态的内容，
通过这个最后修改时间可以判断当前请求的资源是否是最新的。
一般服务端在响应头中返回一个Last-Modified字段，告诉浏览器这个页面的最后修改时间，
浏览器再次请求时会在请求头中增加一个If-Modified-Since字段，询问当前缓存的页面是否是最新的，
如果是最新的就返回304状态码，告诉浏览器是最新的，服务器也不会传输新的数据

#### Etag/If-None-Match

一般用于当Cache-Control:no-cache时，用于验证缓存有效性。

它的作用是让服务端给每个页面分配一个唯一 的编号，然后通过这个编号来区分当前这个页面是否是最新的，
这种方式更加灵活，但是后端如果有多台Web服务器时不太好处理，因为每个Web服务器都要记住网站的所有资源，否则浏览器返回这个编号就没有意义了


## HTTP跨域有哪些？

CORS跨域访问的请求分三种:

- simple request

    如果一个请求没有包含任何自定义请求头，而且它所使用HTTP动词是GET，HEAD或POST之一，那么它就是一个Simple Request。但是在使用POST作为请求的动词时，该请求的Content-Type需要是application/x-www-form-urlencoded，multipart/form-data或text/plain之一。

- preflighted request(预请求)

    如果一个请求包含了任何自定义请求头，或者它所使用的HTTP动词是GET，HEAD或POST之外的任何一个动词，那么它就是一个Preflighted Request。如果POST请求的Content-Type并不是application/x-www-form-urlencoded，multipart/form-data或text/plain之一，那么其也是Preflighted Request。

- requests with credential

    一般情况下，一个跨域请求不会包含当前页面的用户凭证。一旦一个跨域请求包含了当前页面的用户凭证，那么其就属于Requests with Credential。

对于simple request 只需要在后端程序处理时候设Access-Control-Allow-Orgin头就可以了。

对于preflighted request 每次都会请求2次，第一次options（firefox下看不到这次请求，chrome可以看见)。如果只能跟simple request 一样只设置access-control-allow-orgin是不行的。 还必须处理$_SERVER[‘REQUEST_METHOD’] == ‘OPTIONS’，2者都必须处理

## HTTPS的四次握手过程是什么样的？

![](https://static.cyub.vip/images/202010/https_flow.jpeg)

1. 客户端发送问候消息，会告诉客户端支持的tls版本，以及支持的加密算法。
2. 服务端接收到消息后，会将其服务器证书发给客户端
3. 客户端会校验服务器证书是否有授信CA颁发，若是，则会随机生成客户端RSA公私钥，以及会话秘钥。接着客户端会使用服务端加密会话秘钥，并和其公钥一起发送给服务端
4. 服务端接着使用服务器私钥获取客户端会话秘钥，并随机生成服务端会话秘钥，并用客户端私钥加密服务端会话秘钥发送给客户端


之后双方通信都会使用对方的会话秘钥进行对称加密通信。

https握手过程分为两步：

通过CA验证服务端的证书是否真实,交换客户端和服务端的对称加密秘钥，以后数据传输，靠这两个进行加密。引入CA目的是为了防止中间人攻击。即攻击者伪造成服务端，然后发送假的证书。

## 现代浏览器在与服务器建立了一个 TCP 连接后是否会在一个 HTTP 请求完成后断开?什么情况下会断开?

默认情况下建立 TCP 连接不会断开，只有在请求报头中声明 Connection: close 才会在请求完成后关闭连接。在 HTTP/1.0 中，一个服务器在发送完一个 HTTP 响应后，会断开 TCP 链接。但是这样每次请求都会重新建立和断开 TCP 连接，代价过大。所以虽然标准中没有设定，某些服务器对 Connection: keep-alive 的 Header 进行了支持。

## 相比HTTP1，HTTP2有哪些优点？

1. 多路复用

    HTTP/2在一个TCP连接上可以并行的发送多个请求。这是HTTP/2协议最重要的特性，因为这允许你可以异步的从服务器上下载网络资源。许多主流的浏览器都会限制一个服务器的TCP连接数量

2. 请求头压缩

    HTTP2.0可以维护一个字典，差量更新HTTP头部，大大降低因头部传输产生的流量。HTTP/1.1 的首部带有大量信息，而且每次都要重复发送。HTTP/2.0 要求客户端和服务器同时维护和更新一个包含之前见过的首部字段表，从而避免了重复传输。不仅如此，HTTP/2.0 也使用 Huffman 编码对首部字段进行压缩。

    ![](https://static.cyub.vip/images/202107/http2_header.png)

    实现方法是：
    - 维护一份相同的静态字典（Static Table），包含常见的头部名称，以及特别常见的头部名称与值的组合；这个静态字典双方都知道。对于完全匹配的头部键值对，例如 :method: GET，可以直接使用一个字符（字典表的索引id）表示；2）对于头部名称可以匹配的键值对，例如 cookie: xxxxxxx，可以将名称使用一个字符表示。静态字典表见：https://httpwg.org/specs/rfc7541.html#static.table.definition
    - 维护一份相同的动态字典（Dynamic Table），可以动态地添加内容；客户端发送的就是这份动态字典表。

3. 二进制分帧层

    TTP/2.0 将报文分成 HEADERS 帧和 DATA 帧，它们都是二进制格式的。

    ![](https://static.cyub.vip/images/202107/http2_frame.png)

    在通信过程中，只会有一个 TCP 连接存在，它承载了任意数量的双向数据流（Stream）。一个数据流都有一个唯一标识符和可选的优先级信息，用于承载双向信息。消息（Message）是与逻辑请求或响应消息对应的完整的一系列帧。帧（Fram）是最小的通信单位，来自不同数据流的帧可以交错发送，然后再根据每个帧头的数据流标识符重新组装。


    ![](https://static.cyub.vip/images/202107/http2_frame2.png)


4. 服务端推送

    HTTP/2.0 在客户端请求一个资源时，会把相关的资源一起发送给客户端，客户端就不需要再次发起请求了。例如客户端请求 page.html 页面，服务端就把 script.js 和 style.css 等与之相关的资源一起发给客户端。

    ![](https://static.cyub.vip/images/202107/http2_push.png)