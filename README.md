# loguruin

A demo application with login functionality

## License

Copyright (c) UnnamedOrange. Licensed under the MIT License. See the LICENSE file in the repository root for full License text.

## 从零搭一个“最小但完整”的 Flutter 登录应用

很多人第一次在 Flutter 里做“登录”时，真正卡住的并不是按钮怎么画、接口怎么调，而是那些看似琐碎却致命的细节：退出后按返回键居然又回到了主界面；应用启动时先闪一下主界面再跳登录页；登录过期了，主界面里早就启动的异步任务还在跑，最后把状态搅得一团糟。写到后面你会发现，代码并没有“很复杂”，只是“到处都是登录判断”，而且每一处判断都不一样。

这章会以本仓库为例，用尽量贴近“从零开始”的方式，把一个带登录功能的前端应用拆开讲清楚：怎样设计才能保证**状态始终正确**、**维护不痛苦**、**层与层之间不互相绑死**，并且天然**好测试**。读者默认只写过 Flutter 的 `Hello World`，还没做过“登录、缓存、退出、被踢下线、自动跳转”这一套完整流程——没关系，我们就从这套流程为什么会出错讲起。

### 登录为什么总是写着写着就乱了？

如果你把“登录”当成一个按钮的回调函数——点一下按钮、存个 token、跳页面——短期内确实能跑起来。但很快你会遇到一类“行为层面”的 bug：它们不是某行代码写错，而是**状态没有统一来源**导致的连锁反应。

比如你明明点击了退出，界面也跳回了登录页，可是按一下系统返回键，主界面又出现了；或者应用冷启动时先把主界面渲染出来，紧接着又发现没登录，于是立刻跳到登录页——用户肉眼能看到的“闪一下”；再或者更隐蔽：登录已经过期了，但主界面的 `initState()` 里早就起了网络请求、定时器、数据加载，最后这些任务继续跑、继续 setState，界面开始报错、状态开始乱套。

这些现象背后，往往只有一个根因：**“登录状态”没有一个清晰、统一、可追踪的真相来源**。当登录状态被分散在多个页面、多个缓存读取点、多个“我觉得现在是登录的”判断里时，你迟早会得到一个结论：登录不是功能，是架构。

所以我们这章的目标非常明确：把登录状态设计成一件“可管理”的事——全局只有一个真相来源；页面不私自做业务判断；所有需要登录才能执行的异步任务必须先过闸门。

### 先看项目长什么样：为什么要这样分层？

打开 `lib/src` 目录，你会看到类似这样的结构（与本章无关的文件略去）：

```
lib/
  main.dart
  src/
    app/
      app.dart
      splash_page.dart
    routes/
      app_router.dart
      app_routes.dart
    features/
      auth/
        data/
          datasources/
            auth_local_data_source.dart
          repositories/
            auth_repository_impl.dart
        domain/
          models/
            logged_in_user.dart
          repositories/
            auth_repository.dart
        presentation/
          pages/
            login_page.dart
          providers/
            auth_view_model.dart
      home/
        presentation/
          pages/
            main_page.dart
```

这不是“为了好看”而分文件夹，而是为了在一开始就把责任边界画清楚。我们把一个功能按四层拆开，每一层只做它该做的事：

- **View（界面）**只负责呈现与收集输入：显示输入框、按钮，拿到用户名密码。
- **ViewModel（界面状态）**只负责界面要用的状态与动作：当前处于登录中还是已登录，点击按钮要触发什么。
- **Repository（仓库）**用业务语言描述“登录会话”这件事：读取当前用户、保存会话、刷新会话、退出登录。
- **DataSource（数据源）**负责最底层的读写：本例是本地缓存；未来换成网络也不影响上层写法。

依赖方向始终是单向的：

```
界面(View)
  -> 界面状态(ViewModel)
    -> 仓库(Repository)
      -> 数据源(DataSource)
```

这条单向依赖的意义在于：你将来想把“本地模拟”换成“真实服务器”，或者想给登录加更多步骤，上层基本不用大改；写测试时也能从里到外一层一层测，不会被 UI 绑死。

### 真相来源：让 AuthViewModel 成为唯一的“登录状态机”

在这个项目里，登录状态由 `AuthViewModel` 统一管理（`lib/src/features/auth/presentation/providers/auth_view_model.dart`）。它对外暴露的，不是零散的布尔变量，而是一套可以追踪的状态与动作：当前状态 `status`、当前用户 `user`、错误信息 `errorMessage`，以及启动恢复 `bootstrap()`、登录 `logIn()`、刷新会话 `refreshSession()`、退出 `logOut()`。

你可以把它当作一个非常朴素的状态机：所有登录相关的状态变化必须经过它。这样做最直接的好处是——出了问题你不会到处找“是谁把登录状态改掉了”，因为只有一个入口。

更重要的是，ViewModel 基本是纯 Dart 逻辑（除了 `ChangeNotifier`），非常适合写单元测试。你不用启动界面、不用跑模拟器，就能把“登录成功/失败、刷新成功/失败、启动恢复”的状态流转测得很扎实。

### Provider：确保所有页面拿到的是同一个 AuthViewModel

初学者最容易犯的错误之一，是在不同页面里“各自 new 一个 ViewModel”。登录页里创建一份，主界面里再创建一份——看上去没什么，实际上等同于把“真相来源”拆成了多份拷贝：登录页那份认为你已登录，主界面那份却还不知道，状态开始漂移，bug 就从这里长出来。

本项目用 `provider` 把对象放到 Widget 树上，让整个应用里拿到的都是**同一份实例**。你会在 `lib/src/app/app.dart` 里看到 `MultiProvider` 提供 `AuthRepository` 和 `AuthViewModel`。当 ViewModel 内部调用 `notifyListeners()`，使用 `context.watch<AuthViewModel>()` 的界面会自动重建并刷新显示。

在实际写页面时，通常只需要记住两个姿势：

- `context.watch<AuthViewModel>()`：我要监听它的变化（常见于 `build()`）。
- `context.read<AuthViewModel>()`：我只想调用方法，不希望因为它变了而触发这里重建（常见于 `initState()` 或按钮回调）。

### 数据模型：用户是谁，token 什么时候过期？

登录成功后，我们总得保存两类信息：**我是谁**，以及**我凭什么算已登录**。模型定义在 `lib/src/features/auth/domain/models/logged_in_user.dart`：

- `LoggedInUser` 表示用户会话，包含 `id`、`username`、以及 `tokens`。
- `AuthTokens` 包含 `accessToken`、`refreshToken`、以及 `lastRefreshedAt`（上次刷新时间）。

为了把“过期”这个概念讲清楚，本项目在 `auth_local_data_source.dart` 里用一个常量 `kAuthTokenValidity` 定义 token 有效期。你此刻不需要钻进鉴权细节，只要把规则记牢：**超过有效期就视为被踢下线，必须回到登录页**。后面所有设计，都是围绕这条规则不被破坏。

### DataSource：哪怕是本地模拟，也要按“服务器思维”设计

数据源接口与实现位于 `lib/src/features/auth/data/datasources/auth_local_data_source.dart`。这里先定义抽象接口 `AuthDataSource`：它像服务器一样接受参数、返回结果、抛出异常，而不是暴露“我用 SharedPreferences 存了哪些 key”。

接口大致提供这些能力：`logIn(username, password)`、`getSavedUser()`、`refreshTokens()`、`logOut()`。实现类 `AuthLocalDataSource` 用 `shared_preferences` 做本地持久化，你可以把它理解成一个简单的键值存储。但这层真正重要的不是“存哪儿”，而是两条工程习惯：

第一，**过期判断在数据源层就做掉**。`getSavedUser()` 读出缓存后会直接判断是否过期；过期就清理并返回空。这样上层永远只面对“有效会话”或“没有会话”，不用在各处重复写“如果过期就清理”的逻辑。

第二，**用自定义异常表达业务失败**。例如账号密码不合法，抛 `AuthDataSourceException('Invalid credentials')`。上层可以明确区分：这是可预期的业务失败，还是程序崩溃。你的 UI 也才能做出正确提示，而不是一股脑把异常打印到控制台。

很多人一开始会在界面里直接写 `SharedPreferences.getString(...)`。这样做的后果是：UI 变得难测、难换、难维护。把存储细节关进 DataSource，你才有机会在不动 UI 的情况下换实现。

### Repository：让上层只说“业务语言”，别说“存储语言”

仓库接口与实现分别在：

- `lib/src/features/auth/domain/repositories/auth_repository.dart`
- `lib/src/features/auth/data/repositories/auth_repository_impl.dart`

Repository 的存在，是为了让 ViewModel 说人话：登录、取当前用户、刷新会话、退出登录；而不是关心“token 放在哪个 key 里”“先读内存还是先读本地”“过期判断在哪层做”。

本项目的 `AuthRepositoryImpl` 还做了一个非常实用的优化：**内存缓存**。同一次运行里，如果用户信息已经读过，就尽量不再频繁访问本地存储；与此同时它又会在关键点再次做过期判断，避免因为缓存而“假装还登录着”。这会让界面更顺滑，底层读写更少，逻辑也更可控。

### 路由：退出后按返回键为什么不能回去？

只要路由设计不对，前面所有努力都会被一个返回键毁掉。路由相关文件在：

- `lib/src/routes/app_routes.dart`
- `lib/src/routes/app_router.dart`

这里的核心思想很简单：应用任何时刻只允许处于两个“目的地”之一——登录页 `/login`，或主界面 `/main`。当我们从登录跳到主界面，或者从主界面被踢回登录时，**不是在栈顶再 push 一个页面**，而是直接清空导航栈，只留下目标页：

- `pushNamedAndRemoveUntil(..., (_) => false)`

这样做的结果非常“硬”：你退出登录后，主界面已经不在栈里了，按返回键回不去；你登录成功后，登录页也被清掉了，按返回键也回不去。所谓“强制回退”，本质上就是不让错误页面存在于导航历史里。

### 为什么启动一定要有 SplashPage？

启动相关逻辑分布在 `lib/main.dart`、`lib/src/app/app.dart`、`lib/src/app/splash_page.dart`。流程大致是：

1. `main()` 初始化 `SharedPreferences`；
2. 构建 `LoguruinApp`；
3. 在 `LoguruinApp.initState()` 创建 `AuthRepository`、`AuthViewModel`，并执行 `bootstrap()`；
4. 在 `bootstrap()` 完成前显示 `SplashPage`（一个加载圈）；
5. `bootstrap()` 完成后，根据登录状态决定初始路由去登录页还是主界面。

如果你省略 SplashPage，常见后果是：应用先把主界面渲染出来，然后才发现没有会话，又跳回登录页——这就是肉眼可见的闪屏。更糟的是，主界面一旦先被构建，它的 `initState()` 可能已经启动了一堆异步任务，而这些任务本应“未登录不执行”。SplashPage 的意义不只是体验，更是把初始化阶段的状态收口，让应用在做完会话恢复前不进入任何业务页面。

### 最容易被忽略的要求：被踢下线后，主界面异步任务不能继续跑

很多“登录看似做完了”的项目，最后都死在这一条上：应用打开到了主界面，结果发现会话已过期，需要回登录页；可主界面里那些自动启动的异步功能已经跑起来了，甚至继续请求数据，最后 UI 报错或状态乱掉。

把需求翻译成工程规则，其实就一句话：

**任何需要登录才能执行的异步任务，都必须先检查“当前仍然已登录”，并且在每次 `await` 之后再次检查。**

本项目把主界面自动执行的逻辑集中写在 `MainPage` 的 `_ensureSessionValid()`（`lib/src/features/home/presentation/pages/main_page.dart`）。它的节奏是：

- 等页面渲染后再触发（避免 build 里做重活）；
- 如果当前不是已登录，直接返回；
- 如果是已登录，先刷新会话（模拟真实应用里的 refresh token）；
- 刷新成功并且仍然是已登录，才继续加载“会话何时过期”等主界面任务。

伪代码看起来像一个“闸门”：

```
如果不是已登录 -> 直接返回
await 刷新会话
如果刷新失败或变成未登录 -> 直接返回
await 执行真正的主界面异步功能
```

与此同时，应用层（`LoguruinApp`）还会监听 `AuthViewModel` 的状态变化：一旦变成未登录，就用路由把整个应用切回登录页。这样一来，既能保证异步任务不再继续，也能保证界面一定回到正确的地方。

### 界面怎么保持简单，但行为始终正确？

当架构把责任边界画清楚后，UI 反而会变得很“轻”。

登录页 `LoginPage`（`lib/src/features/auth/presentation/pages/login_page.dart`）只需要做三件事：展示输入框与按钮，做最基本的输入校验（比如密码长度），点击按钮时调用 `AuthViewModel.logIn()`。它不去读写缓存，不去决定“登录成功应该跳哪儿”——跳转由应用层统一监听登录状态来处理。这样登录页就很好测：给它一个 ViewModel，输入文本，点按钮，检查 ViewModel 状态变化即可。

主界面 `MainPage`（`lib/src/features/home/presentation/pages/main_page.dart`）包含底部导航栏：Home 展示 `Hello, {userName}`，Settings 展示用户信息并提供退出按钮。退出按钮只调用 `authViewModel.logOut()`；路由切回登录页依然由应用层统一处理。UI 只负责“触发动作”，不负责“做业务决策”。

### 测试为什么会变得顺手？

分层的价值最终会体现在测试上：你不需要一开始就上集成测试或端到端测试，而是可以从内到外逐层验证。

通常的节奏是：先测模型的序列化/反序列化，再测 DataSource 的缓存与过期清理，再测 Repository 的业务语义与内存缓存，再测 ViewModel 的状态流转，最后才测路由与整体行为，端到端测试作为压舱石确认全流程。项目里相应示例包括：

- `test/logged_in_user_test.dart`
- `test/auth_local_data_source_test.dart`
- `test/auth_repository_impl_test.dart`
- `test/auth_view_model_test.dart`
- `test/app_router_test.dart`
- `integration_test/app_test.dart`

运行方式保持简单直接：

- 单元测试：`/Users/orange/flutter/bin/flutter test`
- 端到端测试：`/Users/orange/flutter/bin/flutter test integration_test/app_test.dart -d flutter-tester`

### 将来接入真实服务器，哪里需要动？

如果你把网络请求写在界面里，“接服务器”往往意味着大改 UI、重写流程、补一堆状态判断。但在这套结构下，通常只需要三步：新增一个真正的网络数据源（实现 `AuthDataSource`），在初始化时用它替换 `AuthLocalDataSource`，其余层（Repository、ViewModel、界面、路由、测试结构）大概率不需要动。这就是“最小但完整”的真正含义：现在足够小，未来不困死。

### 收尾：把登录做对，其实就守住两条底线

第一条底线是：**登录状态必须只有一个真相来源**。所有页面只从 `AuthViewModel` 获取状态，不各自保存“我认为的登录状态”。

第二条底线是：**任何需要登录的异步功能必须过闸门**。先确认仍然已登录再执行，并且每次 `await` 之后再确认一次，确保被踢下线后不会继续跑。

守住这两条，你的应用行为会自然变正确：启动时该去哪里就去哪里；退出后回不去不该回去的页面；被踢下线时异步任务不会乱跑；代码层次清晰、维护轻松、测试也更像“工程”而不是“碰运气”。这时你会发现，登录功能并不神秘——它只是需要一个能长期站得住的架构位置。
