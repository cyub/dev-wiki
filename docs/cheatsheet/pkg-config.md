# pkg-config

`pkg-config` 是一个帮助开发人员在编译和链接程序时发现和使用库的辅助工具。它提供了一种方法来获取库的编译和链接参数，使得在编译时链接库变得更加容易和一致。`pkg-config` 通常用于Unix-like系统，并且支持多种编程语言。

`pkg-config` 的工作原理是查询一个名为`.pc`的文件，这些文件包含了关于库的元数据，例如库的安装位置、编译器标志、链接器标志等。当你安装一个库时，通常会在`/usr/lib/pkgconfig`或`/usr/share/pkgconfig`目录下安装相应的`.pc`文件。

## 如何使用 `pkg-config`

### 查询库的编译和链接标志

使用`pkg-config`查询库的编译和链接标志是最常见的用途。例如，如果你想使用`libopus`库，你可以使用以下命令来获取编译和链接标志：

```bash
pkg-config --cflags --libs opus
```

这个命令会输出类似以下内容：

```bash
-I/usr/include/opus -lopus
```

这些标志可以直接在编译命令中使用。

### 编译程序

当你编译程序时，可以将`pkg-config`的输出直接嵌入到编译命令中。例如：

```bash
gcc myprogram.c `pkg-config --cflags --libs opus` -o myprogram
```

这个命令会编译一个名为`myprogram`的程序，并且链接`libopus`库。

如果使用`Makefile`时候，可以通过`pkg-config`动态获取参数：

```makefile
CC = gcc
PKG_CONFIG = pkg-config
CFLAGS = $(shell $(PKG_CONFIG) --cflags opus)
LDFLAGS = $(shell $(PKG_CONFIG) --libs opus)

all: main

main: main.c
	$(CC) main.c $(CFLAGS) $(LDFLAGS) -o main
```

另外进行Go语言的CGO编程时候，我们可以使用 `#cgo` 指令结合 `pkg-config`，来获取链接参数：

```go
/*
#cgo pkg-config: opus
#include <opus/opus.h>
*/
import "C"
```

### 安装和使用.pc文件

如果你正在开发一个库，并且想要让其他程序能够使用`pkg-config`来链接你的库，你需要创建一个`.pc`文件。这个文件通常包含以下内容：

```ini
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib
includedir=${prefix}/include

Name: YourLibrary
Description: A description of your library
Version: 1.0.0
Libs: -L${libdir} -lyourlib
Cflags: -I${includedir}
```

然后，你可以将这个文件安装到`/usr/lib/pkgconfig`或`/usr/share/pkgconfig`目录下。

下面是`libopus`的`.pc`文件内容：

```ini
# Opus codec reference implementation pkg-config file

prefix=/usr
exec_prefix=${prefix}
libdir=${prefix}/lib/x86_64-linux-gnu
includedir=${prefix}/include

Name: Opus
Description: Opus IETF audio codec (floating-point build)
URL: https://opus-codec.org/
Version: 1.3.1
Requires:
Conflicts:
Libs: -L${libdir} -lopus
Libs.private: -lm
Cflags: -I${includedir}/opus
```

### 设置环境变量

在Linux系统中，`.pc`文件的标准位置通常是以下几个目录之一：
    
1. `/usr/lib/pkgconfig`：这是系统默认的库文件搜索路径之一，通常用于存放系统级库的`.pc`文件 。
2. `/usr/share/pkgconfig`：这是另一个系统默认的库文件搜索路径，同样用于存放库的`.pc`文件。
3. `/usr/local/lib/pkgconfig`：当库被安装在`/usr/local`目录下时，相应的`.pc`文件也会存放在这个路径下 。
4. `/usr/lib/x86_64-linux-gnu/pkgconfig`：在某些系统上，特别是64位系统，`.pc`文件可能会存放在这个路径下 。

如果你的`.pc`文件不在标准位置，你可以通过设置`PKG_CONFIG_PATH`这个环境变量来告诉`pkg-config`在哪里查找它们。

```bash
export PKG_CONFIG_PATH=/path/to/your/pkgconfig/files:$PKG_CONFIG_PATH
```

`pkg-config` 是一个非常有用的工具，它可以帮助自动化处理库的发现和使用，使得构建系统更加简洁和易于维护。

### 其他用法

```bash
pkg-config --modversion opus # 查询库版本号

pkg-config --list-all # 查询所有库
```