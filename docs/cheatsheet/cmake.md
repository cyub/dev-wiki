# CMake

CMake是一个跨平台的自动化构建系统，它使用配置文件（CMakeLists.txt）来生成标准的构建文件，如Unix的Makefile或Windows的Visual Studio工程文件。CMake旨在支持多平台源代码编辑和管理，并且可以用于管理复杂项目和大型代码库的构建过程。

CMake的主要特点包括：

1. **跨平台**: 支持在多种操作系统上构建项目，包括Windows、Linux、macOS等。

2. **生成构建系统**: 根据CMakeLists.txt文件生成适用于不同平台的构建系统或IDE项目文件。

3. **可扩展**: 允许用户通过编写自己的CMake模块和脚本来扩展其功能。

4. **查找依赖**: 能够自动查找并配置项目所需的外部库和依赖项。

5. **配置选项**: 提供丰富的配置选项，允许用户自定义构建类型、编译选项等。

6. **安装规则**: 支持定义安装规则，方便软件的打包和分发。

7. **集成测试**: 支持集成测试，确保代码质量。

8. **社区支持**: 拥有一个活跃的社区和丰富的在线资源，包括文档、教程和论坛。

9. **适用于大型项目**: 特别适合于大型项目和多语言支持的项目。

CMake通过提供一套统一的构建和配置接口，简化了在不同平台上编译和构建项目的复杂性，是许多开源项目和商业软件所采用的构建工具之一。

## 安装 CMake

Linux 系统中，可以使用以下方式来安装 CMake：

1. **使用包管理器**:

   大多数Linux发行版的包管理器都有CMake包。例如，在Ubuntu或Debian上，你可以使用以下命令：

   ```bash
   sudo apt-get install cmake
   ```
2. **从源代码编译**:

   你也可以从源代码编译CMake。从[官网](https://cmake.org/download/)下载源代码，然后使用以下命令编译和安装：

   ```bash
   ./bootstrap
   make
   sudo make install
   ```

macOS 系统中可以使用 [Homebrew](https://brew.sh) 来安装CMake：

```bash
brew install cmake
```

Windows 系统中，我们可以访问CMake官网下载页面：https://cmake.org/download/，下载适用于Windows的安装程序。


安装完成后，打开终端输入 `cmake --version` 来验证CMake是否正确安装。

## CMake 语法

CMake的命令和配置写在CMakeLists.txt文件中，它是一个文本文件，它包含了使用 CMake 构建系统的项目的配置和构建指令。每个使用CMake的项目的根目录和每个子目录通常都会有一个CMakeLists.txt文件。


### 最低版本要求

```cmake
cmake_minimum_required(VERSION 3.1)
```

CMake 的版本与它的特性（policies）相互关联，高版本的 Cmake 总会移除掉最低版本不支持的新的特性，所以我们一般使用 CMake 的最新版本，它几乎 完全是向后兼容的。

### 设置一个项目

```cmake
project(MyProject VERSION 1.0
    DESCRIPTION "Very nice project"
    LANGUAGES CXX) # 格式：项目名，版本号，描述，语言
```

默认语言是 `C CXX`。

### 制作一个可执行文件

```cmake
add_executable(one two.cpp three.h)
```

one 是要制作（或者说是构建）的可执行文件的名称，也是创建的 CMake 目标(target)的名称。

### 制作一个库

```cmake
add_library(one STATIC two.cpp three.h) # 语法 ：库名，库类型，源文件
```

库类型可选项有 `STATIC`， `SHARED`， `MODULE`， `OBJECT`，分别对应静态库，动态库，模块，object。我们可以使用 `INTERFACE` 来制作一个接口库，它不能被链接，但可以被其他库依赖。

与add_library相关的一个CMake变量是BUILD_SHARED_LIBS，它表示是否应该生成动态库，用于控制默认情况下是否构建共享库（动态链接库）。 add_library可以用来覆盖该变量行为。

```cmake
set(BUILD_SHARED_LIBS ON) # 默认构建共享库
add_library(my_library STATIC source.cpp) # 显式指定创建静态库
```

### 添加依赖项

```cmake
add_library(another STATIC another.cpp another.h)
target_link_libraries(another PUBLIC one) # 语法：目标名，依赖项类型，依赖项名
```

依赖项类型有 `PUBLIC`， `INTERFACE`，`PRIVATE`，分别对应公开，接口，私有。

当你使用 PUBLIC 关键字时，你指定的库不仅会被当前目标链接，而且这些库也会被传递给任何依赖于当前目标的其他目标，而使用 PRIVATE 关键字指定的库只会被当前目标链接，而不会被传递给依赖于当前目标的其他目标。

举个例子，比如第三个库 third 依赖了 another，而 another 依赖 one 时指定为 PUBLIC，那么 one 库也会被 third 库链接到。

### 添加头文件搜索路径

```cmake
include_directories(${PROJECT_SOURCE_DIR}) # 为整个项目添加头文件搜索路径
target_include_directories(myTarget PRIVATE
  ${PROJECT_SOURCE_DIR}/include
  external/include
) # 为指定目标添加头文件搜索路径
```

通过 target_include_directories 指定的路径会被视为与系统路径等价，这意味着我们既可以 `#include "foo.h"` 引用这个文件，也可以使用  `#include <foo.h>`。


### 设置变量

```cmake
set(MY_VARIABLE "value") # 设置自定义变量
```

访问变量时，使用 `${VAR_NAME}` 语法。我们可以使用message命令来打印变量的值，这有助于调试

```cmake
message("The value of MY_VARIABLE is ${MY_VARIABLE}")
```

### 设置缓存变量

CMake 提供了一个缓存变量来允许你从命令行中设置变量，缓存变量信息会保存到 CMakeCache.txt 文件中。

```cmake
set(MY_CACHE_VARIABLE "VALUE" CACHE STRING "Description") # 只能通过命令行来设置这个变量，它不会覆盖已经定义的值。

set(MY_CACHE_VARIABLE "VALUE" CACHE STRING "" FORCE) # FORCE表示强制覆盖已经存在的变量。这样它会覆盖已经定义的值。

set(CMAKE_CXX_STANDARD 17) # 设置 C++ 标准，CMAKE_CXX_STANDARD 是一个 CMake 内置的缓存变量，它表示 C++ 标准。
```

CMake 中已经有一些预置的变量，像 CMAKE_BUILD_TYPE 就是一个内置缓存变量。下面表格，列出了一些常见的CMake内置变量：

| 变量名称 | 描述 | 分类 |
|---|---|---|
| **CMAKE_VERSION**          | CMake的版本信息，如"3.16.3"。                                   | 版本信息           |
| **CMAKE_SOURCE_DIR**       | 包含顶层CMakeLists.txt文件的目录。                                   | 目录               |
| **CMAKE_BINARY_DIR**       |  由cmake命令创建的输出构建目录                                   | 目录               |
| **CMAKE_CURRENT_SOURCE_DIR** | 当前被处理的CMakeLists.txt所在的目录。                           | 目录               |
| **CMAKE_CURRENT_BINARY_DIR** | 当前目标文件的构建目录。                                          | 目录               |
| **PROJECT_SOURCE_DIR**     | 包含项目主CMakeLists.txt的目录。如果项目是作为子项目包含的，则可能与CMAKE_SOURCE_DIR不同                                | 目录               |
| **PROJECT_BINARY_DIR**     | 项目构建目录。如果项目是作为子项目构建的，则可能与CMAKE_BINARY_DIR不同                                                   | 目录               |
| **CMAKE_HOME_DIRECTORY**   | CMake安装目录。                                                  | 目录               |
| **CMAKE_CACHEFILE_DIR**    | 存储CMake缓存文件的目录。                                         | 目录               |
| **CMAKE_COMMAND**          | 运行当前CMake脚本的CMake可执行文件的路径。                       | 路径               |
| **CMAKE_GENERATOR**        | 指定的CMake生成器，如"Unix Makefiles"或"Ninja"。                 | 构建               |
| **CMAKE_BUILD_TYPE**       | 指定的构建类型，如"Debug"或"Release"。                           | 构建               |
| **CMAKE_SYSTEM**           | 目标平台，如"Linux-x86_64"。                                      | 平台/系统         |
| **CMAKE_SYSTEM_NAME**      | 目标平台的名称，如"Linux"。                                       | 平台/系统         |
| **CMAKE_SYSTEM_PROCESSOR** | 目标平台的处理器，如"x86_64"。                                   | 平台/系统         |
| **CMAKE_SYSTEM_VERSION**   | 目标平台的操作系统版本。                                          | 平台/系统         |
| **CMAKE_C_COMPILER**      | 指定的C编译器的路径。                                             | 编译器             |
| **CMAKE_CXX_COMPILER**    | 指定的C++编译器的路径。                                           | 编译器             |
| **CMAKE_Fortran_COMPILER** | 指定的Fortran编译器的路径。                                       | 编译器             |
| **CMAKE_LINKER**          | 指定的链接器的路径。                                              | 编译器             |
| **CMAKE_AR**               | 指定的归档器（静态库创建器）的路径。                             | 工具               |
| **CMAKE_RANLIB**           | 指定的库索引生成器的路径。                                       | 工具               |
| **CMAKE_INCLUDE_PATH**    | 用于查找头文件的附加搜索路径。                                   | 搜索路径           |
| **CMAKE_LIBRARY_PATH**    | 用于查找库文件的附加搜索路径。                                   | 搜索路径           |
| **CMAKE_PREFIX_PATH**     | 用于查找软件包的路径前缀列表。                                   | 搜索路径           |
| **CMAKE_FRAMEWORK_PATH**  | 用于查找MacOS框架的附加搜索路径。                                | 搜索路径           |
| **CMAKE_PROGRAM_PATH**    | 用于查找可执行程序的附加搜索路径。                               | 搜索路径           |
| **CMAKE_SYSTEM_INCLUDE_PATH** | 系统级别的头文件搜索路径。                                       | 系统搜索路径       |
| **CMAKE_SYSTEM_LIBRARY_PATH** | 系统级别的库文件搜索路径。                                       | 系统搜索路径       |
| **CMAKE_SYSTEM_PROGRAM_PATH** | 系统级别的可执行程序搜索路径。                                   | 系统搜索路径       |
| **CMAKE_MODULE_PATH**     | 用于查找CMake模块文件的路径。                                   | CMake               |
| **CMAKE_ADDITIONAL_MAKE_CLEAN_FILES** | 需要在"make clean"时清理的额外文件列表。                   | 清理               |
| **CMAKE_EXPORT_COMPILE_COMMANDS** | 是否生成compile_commands.json文件。                            | 编译命令           |
| **CMAKE_AUTOMOC**          | 是否自动运行moc（元对象编译器）来处理Qt的信号和槽。           | Qt                |
|  **CMAKE_CXX_STANDARD** |  设置C++标准版本 |  编译控制 | 
|  **CMAKE_CXX_STANDARD_REQUIRED**  |  是否要求指定C++标准版本 |  编译控制 | 
|  **CMAKE_CXX_EXTENSIONS** |  是否允许C++的扩展特性 |  编译控制 | 

### 动态创建配置文件

有时候我们需要动态获取配置信息，比如版本号，编译时间等。这时候我们可以使用`configure_file`函数。`configure_file`函数可以生成一个配置文件，这个配置文件可以包含一些变量，这些变量可以通过CMake变量来设置。例如我们可以生成一个版本信息文件，其中包含版本号和编译时间：

```cmake
configure_file(config.h.in config.h @ONLY) # 配置生成 config.h 文件
```

- config.h.in 是源文件的路径，.in 扩展名表示这是一个模板文件。模板文件中使用@符号包裹要被替换掉的变量。
- config.h 是目标文件的路径，CMake会将 config.h.in 文件复制到目标文件config.h 中，并替换其中的变量。
- `@ONLY` 标志表示只替换@包裹的变量，对于`${VAR}`格式的变量不进行替换。

下面是 config.h.in 文件内容：

```cpp
#ifndef CONFIG_H
#define CONFIG_H
#define BUILD_VERSION @VERSION_MAJOR@.@VERSION_MINOR@.@VERSION_PATCH@
#define BUILD_TIME @BUILD_TIME@
#define BUILD_DIR @BUILD_DIR@
#define BUILD_ARCH @BUILD_ARCH@
#endif
```

下面是 CMakeLists.txt 文件内容：

```cmake
cmake_minimum_required(VERSION 3.5)

project(MyApp CXX)

set(VERSION_MAJOR 0) # 设置版本号
set(VERSION_MINOR 0)
set(VERSION_PATCH 1)
message("Version is ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

execute_process(
    COMMAND date "+%Y-%m-%d %H:%M:%S" # 读取 date 命令输出写入到 BUILD_TIME 变量 中
    OUTPUT_VARIABLE BUILD_TIME
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

execute_process(
    COMMAND pwd # 读取 pwd 命令输出写入到 BUILD_DIR 变量 中
    OUTPUT_VARIABLE BUILD_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

execute_process(
    COMMAND uname -m # 读取 uname -m 命令输出写入到 BUILD_ARCH 变量 中
    OUTPUT_VARIABLE BUILD_ARCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

configure_file(config.h.in config.h @ONLY) # 配置生成 config.h 文件

add_executable(MyApp main.cpp) # 添加可执行文件

target_include_directories(MyApp PRIVATE ${CMAKE_CURRENT_BINARY_DIR}) # 将生成的 config.h 文件添加到编译中
```

执行 `cmake -S . -B build` 命令后我们可以在 build 目录下看到生成 的config.h 文件，其中包含我们设置的版本号、编译时间和编译目录等信息。

### 设置支持的 C++标准

```cmake
set(CMAKE_CXX_STANDARD 17) # 设置C++标准版本为 17
set(CMAKE_CXX_STANDARD_REQUIRED ON) # 要求必须满足C++标准版本要求，否则编译失败
set(CMAKE_CXX_EXTENSIONS ON) # 允许使用C++的扩展特性，否则编译失败
```

我们也可以通过设置编译目标属性来设置支持的 C++标准：

```cmake
set_target_properties(myTarget PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS OFF
)
```

### 设置地址无关代码

用标志 `-fPIC` 来设置地址无关代码（Position independent code）是常见操作的。大部分情况下，你不需要去显式的声明它的值。CMake 将会在 SHARED 以及 MODULE 类型的库中自动的包含此标志。如果你需要显式的声明，可以这么写：

```cmake
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
```

这样会对全局的目标进行此设置，你可以只对某个目标进行设置是否开启此标志。：

```cmake
set_target_properties(lib1 PROPERTIES POSITION_INDEPENDENT_CODE ON)
```

!!! note "什么是位置无关代码，以及它有什么优点？"
    位置无关代码，可以简单理解为代码中的所有地址都是相对于当前位置的， 无绝对跳转，跳转都为相对跳转。

    生成动态库时，需要加上 -fPIC 选项才能生成位置无关代码。位置无关代码优点有：

    - **位置无关代码的共享库实现了真正意义上的多个进程共享**。多个进程引用同一个位置无关动态库时，操作系统会把它们映射到同一块物理内存上，进而实现共享内存。
    - 另外 **位置无关代码支持地址空间布局随机化（ASLR），这是一种安全特性，可以防止缓冲区溢出攻击**。ASLR 通过在每次程序运行时随机化内存中的代码和数据位置来增加攻击者预测目标地址的难度。
    - **位置无关代码使得动态加载和卸载代码模块变得更加容易和安全**。例如，使用 dlopen、dlsym 和 dlclose 等函数动态加载和链接共享库时，位置无关代码是必需的。



### 生成动态库的 SONAME

在生成动态库时，我们通常需要设置 SONAME，即共享库的版本号。SONAME 是一个符号，它表示共享库的版本号，它被保存在动态链接库中，当加载动态库时，动态链接器会根据 SONAME 来确定是否匹配。在 Linux 系统中，SONAME 通常在库文件的头信息中指定，并且可以通过 readelf 命令查看：

```sh
readelf -a /path/to/library.so | grep "SONAME"
```

共享库的版本号可以是任意的，但通常情况下，我们使用 MAJOR.MINOR.PATCH 格式来表示版本号，其中 MAJOR 表示主版本号，MINOR 表示次版本号，PATCH 表示补丁版本号。

如果共享库的格式为：libname.MAJOR.MINOR.PATCH，它对应的 SONAME 的格式一般为：libname.MAJOR。例如，如果共享库的名称是 libfoo.so.2.1.3，那么它的 SONAME 可以设置为 libfoo.2。在 GCC 中，可以使用 -Wl,-soname,libexample.so.1 选项来设置 SONAME。

```cmake
set_target_properties(myLib PROPERTIES POSITION_INDEPENDENT_CODE ON) # 设置为位置无关代码

set_target_properties(myLib PROPERTIES VERSION 2.1.3 SOVERSION 2) # 设置 SONAME
```

### 增加构建子目录

add_subdirectory命令可以用来增加构建子目录。例如，我们可以在项目根目录下创建一个子目录，然后使用add_subdirectory命令来构建子目录：

```cmake
add_subdirectory(subdir)
```

### 下载外部项目依赖

FetchContent是CMake的一个模块，它提供了一种机制来自动下载和包含外部项目作为当前项目的依赖，而无需用户手动下载或管理这些依赖。这个模块在CMake 3.11及以上版本中可用。

```cmake
include(FetchContent)
FetchContent_Declare( # 声明依赖
    fmt # 依赖名称
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git # 依赖的外部项目的仓库地址
    GIT_TAG 11.0.2 # 依赖的外部项目的版本
)

FetchContent_MakeAvailable(fmt) # 下载外部依赖（如果没有下载的话），并包含外部项目（通过add_subdirectory实现）。
```

### 查找外部包

CMake 提供了 find_package 命令来查找外部包。`find_package` 的基本格式如下：

```cmake
find_package(<PackageName> [version] [EXACT] [QUIET] [REQUIRED]
             [[COMPONENTS] [components...]]
             [OPTIONAL_COMPONENTS components...]
             [NO_POLICY_SCOPE])
```

- REQUIRED：如果未找到包，则会生成错误。
- QUIET：如果未找到包，则不会显示警告信息。
- COMPONENTS：用于指定库的特定组件

例如我们可以使用 find_package 命令来查找 OpenCV 库：

```cmake
find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})
target_link_libraries(myTarget ${OpenCV_LIBS})
```

下面是查找数学库的示例：

```cmake
find_library(MATH_LIBRARY m)
if(MATH_LIBRARY)
    target_link_libraries(MyTarget PUBLIC ${MATH_LIBRARY})
endif()
```

`find_package` 其工作原理主要依赖于两种模式：Module模式和Config模式。

- **Module模式**：
    
    在这种模式下，find_package 会查找名为 `Find<LibraryName>.cmake` 的文件。CMake首先在CMAKE_MODULE_PATH指定的路径中搜索该文件，如果未找到，则会在CMake自带的模块目录中查找。

    该文件负责查找库的头文件和链接库，并将相关信息存储在特定变量中，例如`<NAME>_FOUND`、`<NAME>_INCLUDE_DIRS`和`<NAME>_LIBRARIES`等。这些变量随后可以在CMakeLists.txt中使用，以便进行编译和链接

- **Config模式**：

    如果Module模式未能找到所需的库，CMake会转入Config模式。在此模式下，CMake查找名为`<LibraryName>Config.cmake`或`<lower-case-package-name>-config.cmake`的文件。
    
    这些配置文件通常由库的开发者提供，包含了库的必要信息，如头文件和库文件的路径。使用Config模式时，用户可以通过指定CONFIG关键字来明确请求此模式

### 安装

在CMake中，install命令用于指定在安装目标（可执行文件、库、文件等）时应该如何复制文件和目录。这使得软件包的安装过程可以自动化，并且确保所有必要的文件被放置在正确的位置。install 命令相关语法如下：

**安装目标的到指定目录**：

```cmake
install(TARGETS targets ... [EXPORT <export-name>]
        [RUNTIME_DEPENDENCIES args...|RUNTIME_DEPENDENCY_SET <set-name>]
        [[ARCHIVE|LIBRARY|RUNTIME|OBJECTS|FRAMEWORK|BUNDLE|
          PRIVATE_HEADER|PUBLIC_HEADER|RESOURCE]
         [DESTINATION <dir>]
         [PERMISSIONS permissions...]
         [CONFIGURATIONS [Debug|Release|...]]
         [COMPONENT <component>]
         [NAMELINK_COMPONENT <component>]
         [OPTIONAL] [EXCLUDE_FROM_ALL]
         [NAMELINK_ONLY|NAMELINK_SKIP]
        ] [...]
        [INCLUDES DESTINATION [<dir> ...]]
        )
```

- TARGET targets: 指定要安装的target.
- ARCHIVE|LIBRARY|RUNTIME等： 指定target的类型。
- DESTINATION dir: 指定要安装到的路径。当使用相对路径时，是相对于变量CMAKE_INSTALL_PREFIX的, 该变量默认为/usr/local/, 也可以在CMakeLists.txt中指定，也可以在运行CMAKE命令时指定，例如：cmake .. -DCMAKE_INSTALL_PREFIX=/install/location

**安装指定文件到指定目录**：

```cmake
install(<FILES|PROGRAMS> files...
        TYPE <type> | DESTINATION <dir>
        [PERMISSIONS permissions...]
        [CONFIGURATIONS [Debug|Release|...]]
        [COMPONENT <component>]
        [RENAME <name>] [OPTIONAL] [EXCLUDE_FROM_ALL])
```


- FILES files: 指定要安装的文件。
- DESTINATION dir: 指定要安装的路径。

**安装目录到指定目录中**：

```cmake
install(DIRECTORY dirs...
        TYPE <type> | DESTINATION <dir>
        [FILE_PERMISSIONS permissions...]
        [DIRECTORY_PERMISSIONS permissions...]
        [USE_SOURCE_PERMISSIONS] [OPTIONAL] [MESSAGE_NEVER]
        [CONFIGURATIONS [Debug|Release|...]]
        [COMPONENT <component>] [EXCLUDE_FROM_ALL]
        [FILES_MATCHING]
        [[PATTERN <pattern> | REGEX <regex>]
         [EXCLUDE] [PERMISSIONS permissions...]] [...])
```

- DIRECTORY dirs: 指定要安装的头文件的目录路径，默认为相对于当前的路径。 如果路径以/结尾时，会把路径里面的内容复制到给定路径，如果没有以/结尾，则会会复制该目录。
- DESTINATION: 要安装到的目录路径。

下面是一些使用示例：

```cmake
install(TARGETS my_executable RUNTIME DESTINATION bin) # 安装可执行文件

install(TARGETS my_library ARCHIVE DESTINATION lib LIBRARY DESTINATION lib) # 安装库文件

install(FILES my_header.h DESTINATION include) # 安装头文件

install(DIRECTORY data/ DESTINATION share/my_package/data) # 安装指定目录
```

## 运行 CMake

### 构建项目

经典 CMake 构建流程：

```bash
mkdir build
cd build
cmake ..
make # 与 cmake --build . 操作等效
```

新版 CMake 构建流程：

```bash
cmake -S . -B build # 生成构建目录，-B指定待生成的构建目录， -S 指定源码目录
cmake --build build # 构建，--build指定构建目录
```

我们可以通过环境变量执行编译器：

```bash
 CC=clang CXX=clang++ cmake ..
```

#### 设置生成器

CMake Generators是CMake构建系统用来指定如何生成构建文件的一套工具。当你使用CMake来配置项目时，Generator定义了输出构建系统的具体类型，这通常依赖于你想要使用的构建工具和开发环境。


通过`cmake --help`命令可以查看所有CMake支持的生成器。以下是一些常见的CMake Generators：

- Unix Makefiles：
        
    这个Generator生成标准的Makefiles，适用于Unix-like系统（如Linux和macOS）以及使用Gnu Make的Windows环境。

- Ninja：

    Ninja是一个小型的专注于速度的构建系统，它可以生成比传统Makefiles更快的构建过程。

- Visual Studio：

    这个Generator为不同版本的Visual Studio IDE生成解决方案（.sln）和项目文件（.vcxproj），适用于Windows开发。

- Xcode：

    为macOS的Xcode IDE生成.xcodeproj项目文件。

我们可以通过`-G`参数指定生成器，也可以使用环境变量`CMAKE_GENERATOR`来指定生成器：

```bash
cmake -G Ninja .. // 指定Ninja生成器
```

### 执行安装

通过上面命令构建完成之后，我们可以使用下面命令进行安装：

```bash
# 如果当前在build 目录下面
make install
cmake --build . --target install
cmake --install . # CMake需3.15+支持

# 如果当前在源码目录下面
make -C build install
cmake --build build --target install
cmake --install build # CMake 3.15+ only
```


### 设置选项

在 CMake 中，你可以使用 -D 设置选项。你能使用 -L 列出所有选项，或者用 -LH 列出人类更易读的选项列表。如果你没有列出源代码目录或构建目录，这条命令将不会重新运行 CMake（使用 cmake -L 而不是 cmake -L .）。

CMake 支持缓存选项。CMake 中的变量可以被标记为 "cached"，这意味着它会被写入缓存（构建目录中名为 CMakeCache.txt 的文件）。你可以在命令行中用 -D 预先设定（或更改）缓存选项的值。CMake 查找一个缓存的变量时，它就会使用已有的值并且不会覆盖这个值。

#### 标准选项

大部分软件包中都会用到以下的 CMake 选项：

- CMAKE_BUILD_TYPE：用于指定项目的构建类型，默认为 Release。常见可能值有：

    - Debug: 启用调试信息的生成，优化级别较低，通常用于开发和调试。
    - Release: 关闭调试信息，启用更高级别的优化，用于生成发布版本的软件。
    - RelWithDebInfo: 同时包含发布版优化和调试信息，适用于需要优化性能但也需要调试信息的场景。
    - MinSizeRel: 最小化生成的可执行文件或库的大小，通常用于需要最小化部署体积的场景。
- CMAKE_INSTALL_PREFIX：用于指定安装位置。UNIX 系统默认的位置是 /usr/local，用户目录是 ~/.local
- BUILD_SHARED_LIBS： 用于控制共享库的默认值，值为 ON 或者 OFF。值为 ON 时默认生成动态库，否则生成静态库。
- BUILD_TESTING: 用于设置启用测试的通用名称
- CMAKE_CXX_STANDARD：用于指定 C++ 标准版本，默认为 11。

下面命令会设置默认的构建类型为 Release，安装位置为 /usr/local，编译器为 clang++，C++ 标准为 17，启用测试，生成动态库：

```bash
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_CXX_COMPILER=clang++\
 -DCMAKE_CXX_STANDARD=17 -DBUILD_TESTING=ON -DBUILD_SHARED_LIBS=ON ..
```

## 参考资料

- [Modern CMake 简体中文版](https://modern-cmake-cn.github.io/Modern-CMake-zh_CN/)
- [cmake 常用指令入门指南](https://www.cnblogs.com/yinheyi/p/14968494.html)
- [CMake 官方文档](https://cmake.org/cmake/help/latest/)
- [CMake 教程](https://cmake.org/cmake/help/latest/guide/tutorial/index.html)

另外借助了 AI 工具：[perplexity AI](https://www.perplexity.ai) 、 [kimi](https://kimi.moonshot.cn)，以及 VSCode 的插件：[TONGYI Lingma](https://marketplace.visualstudio.com/items?itemName=Alibaba-Cloud.tongyi-lingma)

