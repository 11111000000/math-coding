# 区别 — mathcoding 与其他方法论的比较

> **本页是什么。** 对 mathcoding 与下列方法的逐点比较：规约驱
> 动开发、决策记录、领域驱动设计、行为驱动开发、形式化方法、
> 架构框架、保障成熟度模型。每个章节都会指出对方方法做得好的
> 地方，以及 mathcoding 补充、拒绝或改变的地方。

## 一句话回答

**mathcoding 是一个保障协议（assurance protocol），而不是规
约语言，也不是文档系统。** 大多数方法论描述"应该构建什么"或
"团队应该如何工作"。mathcoding 把每一次变更都绑定到一个被记
录下来的承诺、一组义务、一份有限定的证据，以及由一个确定性
内核所产出的判定。在其他方法论可能漂移的地方，mathcoding 不
会 —— 内核要么让变更通过，要么不放行；判定会引用规则、主体、
原因与补救手段。

## 没有任何方法论同时具备的三项属性

mathcoding 并不是其他方法论能力的简单加总。它是其他任何方法
论都没有同时提供的三项属性的特定组合：

1. **有限定的证据。** 每条声明都受主体、义务、输入、环境、
   实现的摘要、方法与时间限定。没有限定的声明不是声明，而是
   意愿的表达。
2. **诚实的不确定性。** 缺乏证据是 `Inconclusive`，而不是
   `Pass`。`Pass ≠ Fail ≠ Inconclusive ≠ InfrastructureError`。
   `Waived ≠ Pass`。`Reviewed ≠ Observed`。五种来源类别
   （`declared ≠ derived ≠ attested ≠ reviewed ≠ observed`）
   不可相互合并。
3. **自应用。** 治理 mathcoding 的规则同时治理 mathcoding 本
   身。对宪法、模式、内核或闸门规则的修改是一种*受保护策略转
   换*，需要：在先前政策下做出的决策、最强反例、正负两面固件
   （fixture）、迁移路径、恢复路径、先前授权以及一份判定差异
   清单。

如果某方法论只具备其中一项，mathcoding 就继承那一块。如果具
备两项，mathcoding 就把第三项收紧。如果同时具备三项，那它要
么是 mathcoding，要么是它的派生。

## 一览对比

| 方法论 | 它所断言的内容 | mathcoding 补充的内容 |
|---|---|---|
| TDD | 测试先于代码 | 测试用于验证义务，而非行为；义务可被版本化与可被检查 |
| BDD | 行为以 Given/When/Then 表达 | 仅行为不够；内核会问：谁观察到了、何时观察到的 |
| DDD | 代码反映领域 | 领域模型是一种决策；内核对它的变更把关 |
| FDD | 特性是规划单位 | 特性即决策；义务即特性必须保留的属性 |
| MDD / MDA | 模型生成代码 | 模型是证据，不是真理之源；真理之源是决策 |
| Spec-Driven Development | 规约先于代码 | 没有证据的规约只是愿望；mathcoding 闭合回路 |
| ADR (Nygard / MADR) | 决策以 Markdown 记录 | 记录是带有模式、义务与可验证判定的 YAML 包 |
| arc42 | 十二节架构文档 | 每一节是可选义务；除非现行政策要求，否则不强制 |
| C4 Model | 四个缩放层级的图 | 图属于 `attested` 证据；义务是图所必须保留的属性 |
| Living Documentation | 文档由代码生成 | 活文档只是一种来源类别；mathcoding 也接纳其他类别 |
| Specification by Example | 示例锁定契约 | 示例是一种证据；契约是义务，示例是见证 |
| OpenAPI | API 以机器可读形式描述 | 描述只是一个义务；其他义务覆盖行为、安全与新鲜度 |
| Design by Contract | 每个调用都有前置/后置条件 | 契约是函数上的义务；mathcoding 把义务扩展到决策、证据与 waiver |
| Formal Methods（TLA+、Coq…） | 属性在证明助手中被证明 | 证明是一种证据；义务可以属于 review、test 或 observation 类别 |
| TOGAF | 企业架构框架 | mathcoding 是闸门；TOGAF 描述闸门所读取的元模型 |
| ISO/IEC/IEEE 42010 | 架构描述标准 | 42010 命名关注点；mathcoding 把每个关注点绑定到义务与验证器 |
| Team Topologies | 软件团队的组织结构 | Team Topologies 命名认知负载；mathcoding 命名每次变更所产生的摩擦 |
| SAFe | 规模化敏捷过程 | SAFe 命名仪式；mathcoding 把每个仪式的产物绑定到验证器与证据 |
| OWASP SAMM | 软件保障成熟度模型 | SAMM 评估组织；mathcoding 评估每一次变更 |
| NIST SSDF | 安全开发实践 | SSDF 命名实践；mathcoding 让每次变更都可被检查 |

本表是摘要，下面的小节会逐行展开。

## 1. TDD — 测试驱动开发（Kent Beck，2002）

TDD 先写一个失败的测试，让它通过，再重构。纪律局部于一个单
元；测试是契约；重构是"在不破坏契约的前提下修改实现"的自由。

**mathcoding 继承了什么：** "测试即证据"的理念。一份
`kind: test` 的 mathcoding 证据在协议层面相当于被提升为一级
制品的 TDD 测试：它携带着生产者身份、方法、实现的摘要与判定。

**mathcoding 补充了什么：** 测试被绑定到某个具体的`义务`，而
非行为。义务命名测试必须保留的*属性*；测试命名内核运行的
*检查*。如果测试通过，但该义务未在任何生效决策中被命名，则该
测试不参与保障回路 —— 它只是一个内部制品。TDD 把每个测试当
作契约；mathcoding 要求契约必须在决策中声明。

**mathcoding 拒绝什么：** "测试通过 ⇒ 系统正确"这一隐含断
言。在 mathcoding 中，`pass` 只是一个义务的判定；绿色测试集
是见证，不是判定。

## 2. BDD — 行为驱动开发（Dan North，2003）

BDD 用团队与业务共享的自然语言子集 `Given / When / Then` 来
表达行为。纪律是场景；执行器是 Cucumber、SpecFlow 或 Behave。

**mathcoding 继承了什么：** "场景即规约"的理念。一个 mathcoding
义务可以在 `verifier: bdd-scenario` 字段中表达为一个
`Given/When/Then` 场景；内核接受该场景，将其与义务配对，并
把场景的产出视为义务的判定。

**mathcoding 补充了什么：** 场景的产出是五个值之一，而非两
个。`Pass`、`Fail`、`Inconclusive`、`InfrastructureError`、
`Waived` 互不相同；"已经通过的"但执行器未运行的场景是
`Inconclusive`，不是 `Pass`。BDD 把"场景运行时通过"和"行为
已验证"混为一谈；mathcoding 把这两件事分开。

**mathcoding 拒绝什么：** "业务可读的场景就是验证"这一假设。
场景易读但难验证；mathcoding 把它视为一种证据，带有通常的
`producer_identity` 与 `environment` 限定。

## 3. DDD — 领域驱动设计（Eric Evans，2003）

DDD 把代码建模在领域上：限界上下文、统一语言、聚合、领域事
件。纪律是*对话式的*；制品是代码、图与术语表。

**mathcoding 继承了什么：** 一种命名事物的纪律，使得内核与
人能够一致。mathcoding `决策` 携带着 `意图` 与 `承诺`；两者
都以团队的统一语言写就。

**mathcoding 补充了什么：** 内核不知道领域，它知道决策。限界
上下文是一个决策；统一语言是决策所共有的属性；聚合是闸门保护
的路径命名空间。DDD 命名形态；mathcoding 在该形态上设置闸门。

**mathcoding 拒绝什么：** "良好建模的领域就是被验证的系统"这
一假设。正确但没有义务的模型是愿望；正确且有义务但没有证据
的模型是假设。mathcoding 索取第三个制品。

## 4. FDD — 特性驱动开发（De Luca & Coad，1997）

FDD 一项特性一项特性地构建系统；每项特性由小团队界定、设
计、实现。纪律是特性列表；制品是工作中的增量。

**mathcoding 继承了什么：** 特性作为规划单位。mathcoding 决策
可以声明 `feature_id`；义务是特性必须保留的属性。

**mathcoding 补充了什么：** 特性携带着 `验证器` 与 `判定`。
FDD 追踪进度；mathcoding 追踪验证。内核度量的不是速率，而是
义务判定。

**mathcoding 拒绝什么：** "特性已构建 ⇒ 特性已验证"这一隐含
断言。构建是 `变更`；验证是 `证据`；两者是不同的种类。

## 5. MDD / MDA — 模型驱动开发 / 模型驱动架构（OMG，2001）

MDD/MDA 从平台无关模型（PIM）与平台相关模型（PSM）生成代
码。纪律是模型；制品是生成的代码。

**mathcoding 继承了什么：** 模型作为一级制品。mathcoding 决策
可以声明一个 `model` 字段；模型是内核会对其求摘要的若干底层
之一。

**mathcoding 补充了什么：** 模型是证据，不是真理之源。真理之
源是决策；模型只是一种证据。如果模型与代码不一致，输的是代
码（因为义务是代码必须保留的属性，而不是模型必须保留的属
性）。MDD/MDA 把模型当作源头；mathcoding 把模型当作见证。

**mathcoding 拒绝什么：** "生成的代码就是已验证的代码"这一假
设。生成器是方法；生成的制品是摘要；验证是另一份证据。

## 6. Spec-Driven Development（GitHub Spec Kit、AWS Kiro，2025）

Spec-Driven Development（SDD）是 2025 年工业界对一类方法论的
称呼：它们以规约开头 —— 一个 Markdown 文件描述特性、验收标准
与测试计划。GitHub Spec Kit、AWS Kiro、GitLab Duo 以及若干商
业编程代理采用这种形态。纪律是规约；制品是规约加上生成的代
码。

**mathcoding 继承了什么：** "规约即真理之源"的理念。mathcoding
决策的 `承诺` 在协议层面就是规约 —— 一条关于变更属性的可证伪
声明。

**mathcoding 补充了什么：** 规约被绑定到 *验证器* 与 *判定*。
SDD 产出规约与代码变更；规约由测试验证，但测试并非由该方法
论本身与规约绑定。规约可能仅在名义上被遵守；mathcoding 义务
则不然 —— 内核在每次闸门检查证据。

**mathcoding 拒绝什么：** "规约被写出就是验证"这一隐含断言。
在 SDD 中，"规约已写"是里程碑；在 mathcoding 中，"规约已写"
是回路的起点而非终点。没有通过证据的规约是 `Inconclusive` 义
务，不是 `Pass`。

**这是最近的现役竞争者。** SDD 是缺少有限定证据纪律的同形
方法。如果你读 SDD 时心想"如果加上证据类别、waiver 过期机制
和确定性闸门就更好了"，那你就读出了 mathcoding 的差异。

## 7. ADR — 架构决策记录（Michael Nygard，2011；MADR，2018）

ADR 把每一项重要的架构决策记录为一份带 `Context`、`Decision`、
`Consequences`、`Status` 的短 Markdown 文件。MADR 进一步扩展，
加入选项、决策驱动因子与确认流程。纪律是记录；制品是文件。

**mathcoding 继承了什么：** "决策即制品"的理念。mathcoding
`决策` 是 ADR 的形态再加上模式、必备的义务列表与确定性闸
门。`mathc import-adr` 是一级工具，可将 MADR 与 adr-tools 文
件转换为 mathcoding 包。

**mathcoding 补充了什么：** 决策携带着 `义务` 与 `证据`。内
核对每个决策相对于其义务在每次闸门进行检查；无义务的决策是
信息性的，不构成阻塞；有义务但无证据的决策是 `Inconclusive`。
ADR 是笔记本；mathcoding 是带检查器的笔记本。

**mathcoding 拒绝什么：** "写过的 ADR 就是已验证的 ADR"这一假
设。`Context / Decision / Consequences` 是一份声明；内核读取
声明并追问"什么证据表明该声明仍然成立？"。答案就是证据。

**这是最近的结构竞争者。** ADR 是 mathcoding 的上游。ADR 是
人可读且非类型化的；mathcoding 是机器可读、按模式校验、闸门
检查的。ADR 的 "Status: superseded" 是一行字符串；mathcoding
的 `supersedes` 是内核可以遍历的修订 DAG 上的一种关系。

## 8. arc42 — 十二节架构文档（Gernot Starke，Peter Hruschka）

arc42 是软件架构文档的模板：十二节内容，从
`Introduction and Goals` 一直到 `Risks and Technical Debts`。
纪律是模板；制品是填好的文档。

**mathcoding 继承了什么：** "节即命名空间"的理念。mathcoding
决策可以声明 `arc42_section`；义务是该节必须保留的属性。

**mathcoding 补充了什么：** 除非现行政策要求，否则不强制使
用。arc42 给出十二节；mathcoding 不给出任何节，并请现行政策
声明项目在意哪些节。默认空的态度正是 A0 分离公理的体现：种
类各异，文档是不同于决策的另一种类。

**mathcoding 拒绝什么：** "填好模板就是验证"这一假设。模板是
结构；验证是验证器。mathcoding 用检查取代结构。

## 9. C4 Model — Context、Containers、Components、Code（Simon Brown，2011）

C4 是一套层级化的图方案：系统上下文、容器、组件、代码。纪律
是图；制品是图集。

**mathcoding 继承了什么：** "缩放层级"的理念。mathcoding 决策
可以声明 `c4_level`；义务是该层级图必须保留的属性。

**mathcoding 补充了什么：** 图是 `证据` 而非 `决策`。图可以证
明系统具有某种形态；决策声明形态，义务命名属性，图是见证。
C4 把形态与见证混在一起；mathcoding 把它们分开。

**mathcoding 拒绝什么：** "当下的图就是已验证的图"这一假设。
图会老化，义务不会。义务上的 `valid_until` 字段是让图在时间
维度上保持诚实的关键。

## 10. Living Documentation（Cyrille Martraire）

Living Documentation 是从代码生成文档的实践：测试、类型、示
例、场景。纪律是生成器；制品是文档。

**mathcoding 继承了什么：** "文档即副产品"的理念。mathcoding
证据可以携带 `producer: living-doc` 字段；活文档是一种证据。

**mathcoding 补充了什么：** 活文档是五种来源类别之一，不是唯
一。`declared`（顾问）、`derived`（生成器）、`attested`（测
试）、`reviewed`（人）、`observed`（运行时）互不相同；mathcoding
接纳全部五种，并拒绝在没有制品的情况下把 `derived` 提升为
`observed`。

**mathcoding 拒绝什么：** "生成的文档就是已验证的文档"这一假
设。生成器是方法；输出是摘要；验证是另一份证据。

## 11. Specification by Example（Gojko Adzic）

Specification by Example（SBE）把契约写成示例：输入、输出、边
界场景。纪律是示例；制品是可执行的规约。

**mathcoding 继承了什么：** "示例即规约"的理念。mathcoding 义
务可以在 `acceptance.examples` 中表达为一组示例；内核接受这
些示例并将每一个视为固件。

**mathcoding 补充了什么：** 示例只是证据的一种，不是唯一。SBE
把示例当作验证；mathcoding 把示例当作见证，把义务当作契约。
两者是不同的种类。

**mathcoding 拒绝什么：** "通过的示例集就是已验证的系统"这一
假设。示例集由输入限定；义务不受此限。保留示例集但破坏了义
务所命名之属性的变更，在 mathcoding 中是 `Fail`，在 SBE 中是
`Pass`。

## 12. OpenAPI — 机器可读的 API 规约

OpenAPI 用 YAML 或 JSON 描述 HTTP API：路径、方法、参数、响
应、模式。纪律是描述；制品是规约文件与生成的客户端/服务端
桩。

**mathcoding 继承了什么：** 机器可读契约的理念。mathcoding 决
策可以声明 `openapi_spec`；义务是 API 必须保留的属性。

**mathcoding 补充了什么：** OpenAPI 规约只是一条义务；其他义
务覆盖行为、安全、新鲜度与向后兼容。OpenAPI 描述形态；
mathcoding 把形态绑定到验证器与判定。绿色的 OpenAPI lint 是
`Inconclusive` 义务，不是 `Pass` —— 契约可能满足，行为未必。

**mathcoding 拒绝什么：** "生成的客户端就是已验证的客户端"这
一假设。生成器是方法；生成的制品是摘要；验证是另一份证据。

## 13. Design by Contract（Bertrand Meyer，Eiffel，1986）

Design by Contract（DbC）将前置条件、后置条件与不变量附加到
每项操作上。纪律是契约；制品是契约直接写于其中的代码。

**mathcoding 继承了什么：** "契约即属性"的理念。mathcoding 义
务可以表达为 `dbc:precondition` 或 `dbc:postcondition` 字段；
内核接受契约并把运行时检查当作验证器。

**mathcoding 补充了什么：** 契约落在*决策*之上，而不是函数之
上。决策携带一个或多个义务；每个义务都可以表达为 DbC 契约。
mathcoding 还对证据、waiver、修订加上义务 —— 这些种类是 DbC
所没有的。DbC 是契约纪律；mathcoding 是契约纪律 + 验证器纪
律 + 恢复纪律。

**mathcoding 拒绝什么：** "运行时 DbC 检查通过就是系统通过"这
一假设。运行时检查是一种证据，由触发它的输入所限定；义务不
受此限。保留运行时检查但破坏义务所命名之属性的变更，在
mathcoding 中是 `Fail`，在 DbC 中是 `Pass`。

**这是结构上紧密的近邻。** DbC 与 mathcoding 共享以属性为核
心的正确性观。差异在于：mathcoding 的属性落在决策、证据与
waiver 之上 —— 不止于函数。

## 14. Formal Methods — TLA+、Coq、Isabelle、Lean、Alloy

形式化方法用形式语言表达规约并证明（或模型检查）其属性。纪
律是证明；制品是证明脚本与证书。

**mathcoding 继承了什么：** "证明即证据"的理念。mathcoding 证
据可以携带 `producer: tla+ | coq | isabelle` 字段；证明是一
种证据。

**mathcoding 补充了什么：** 证明只是证据的一种，不是唯一。形
式证明是 `Pass` 证据；非形式评审是 `Review` 证据；运行时观察
是 `Observed` 证据。三者各不相同；mathcoding 接纳全部三种，
并拒绝在没有制品的情况下把 `Review` 提升为 `Observed`。

**mathcoding 拒绝什么：** "被证明的属性就是被验证的系统"这一
假设。证明受模型限定；模型受规约限定；规约受决策限定。位于
与决策不符之模型中的被证属性，在 mathcoding 中是 `Stale` —
证据是诚实的，但底层已经改变，内核会重新评估。

**这是最深的近邻。** 形式化方法与 mathcoding 共享有限定证据
的纪律。差异在于范围：形式化方法证明模型上的属性；mathcoding
把决策绑定到任何种类的验证器（测试、评审、观察、证明、运行
时信号），并拒绝在种类之间提升判定。

## 15. TOGAF — The Open Group 架构框架

TOGAF 是企业架构框架：架构开发方法（ADM）、架构内容框架、企
业连续体。纪律是 ADM 循环；制品是架构描述。

**mathcoding 继承了什么：** "架构即内容"的理念。mathcoding 决
策可以声明 `togaf_phase`；义务是该阶段必须产出的属性。

**mathcoding 补充了什么：** TOGAF 命名阶段；mathcoding 命名验
证器。TOGAF 阶段 A（架构愿景）没有验证器就是愿望；mathcoding
决策命名阶段 A 并声明验证器就是检查。TOGAF 是元模型；
mathcoding 是读取元模型的闸门。

**mathcoding 拒绝什么：** "完成的 ADM 循环就是已验证的架构"这
一假设。循环是过程；验证是逐制品的。mathcoding 用逐制品的
义务取代循环。

## 16. ISO/IEC/IEEE 42010 — 架构描述标准

ISO/IEC/IEEE 42010 是架构描述的国际标准：利益相关方、关注
点、视点、视图、对应规则、语言。纪律是架构描述；制品是架构
描述文档。

**mathcoding 继承了什么：** "关注点即属性"的理念。mathcoding
义务可以声明 `iso42010_concern`；义务是架构必须满足该关注点
的属性。

**mathcoding 补充了什么：** 42010 命名关注点；mathcoding 把关
注点绑定到验证器。符合 42010 但无验证器的架构描述是文档；同
时命名关注点与验证器的 mathcoding 决策是检查。42010 是元模
型；mathcoding 是闸门。

**这是基于标准的最深近邻。** 42010 与 mathcoding 共享以关注
点为导向的架构观。差异在于义务的种类：42010 的义务落在描述
上；mathcoding 的义务落在变更、证据、waiver 与修订上。

## 17. Team Topologies（Matthew Skelhorn，Manuel Pais）

Team Topologies 是软件团队的组织设计：四类团队（stream-aligned、
enabling、complicated-subsystem、platform）、三种交互模式
（collaboration、X-as-a-Service、facilitating）以及认知负载
模型。纪律是团队结构；制品是团队拓扑与团队间协议。

**mathcoding 继承了什么：** 认知负载模型。mathcoding `模式`
（tiny / light / standard / strict / exhaustive）是风险函数，
而风险是变更施加于团队之认知负载的函数。

**mathcoding 补充了什么：** Team Topologies 命名负载；mathcoding
命名负载所产生的摩擦。Team Topologies 归类为 `facilitating` 的
变更，在 mathcoding 中是 `record` 摩擦；跨越团队边界的变更是
`ask` 摩擦；触及宪法规则的变更是 `block` 摩擦。两者互相对应，
但 mathcoding 的摩擦是逐变更的，不是逐团队的。

**mathcoding 拒绝什么：** "良好结构的团队就是验证中的团队"这
一假设。结构是组织的属性；验证是变更的属性。在 stream-aligned
团队中的变更，如果缺失证据就仍是 `Inconclusive`，与团队结构
无关。

## 18. SAFe — 规模化敏捷框架

SAFe 是敏捷的规模化框架：配置等级（Essential、Large、
Portfolio）、角色、仪式、制品。纪律是仪式节奏；制品是
Program Increment（PI）计划与迭代产出。

**mathcoding 继承了什么：** 节奏的理念。mathcoding 决策可以声
明 `safe_pi`；义务是 PI 必须保留的属性。

**mathcoding 补充了什么：** SAFe 命名仪式；mathcoding 把制品
绑定到验证器。没有验证器的 PI 计划是愿望；同时命名 PI 制品与
验证器的 mathcoding 决策是检查。SAFe 是过程；mathcoding 是逐
制品的检查。

**mathcoding 拒绝什么：** "完成的 PI 就是已验证的 PI"这一假
设。PI 是过程产出；验证是逐制品的。mathcoding 用逐制品的义
务取代过程闸门。

## 19. OWASP SAMM — 软件保障成熟度模型

OWASP SAMM 是软件保障的成熟度模型：五个业务职能
（Governance、Design、Implementation、Verification、
Operations），每个职能有三类安全实践，每个实践有三级成熟
度。纪律是成熟度阶梯；制品是 SAMM 评估。

**mathcoding 继承了什么：** 保障职能的理念。mathcoding 决策可
以声明 `samm_function`；义务是职能必须满足的属性。

**mathcoding 补充了什么：** SAMM 评估组织；mathcoding 评估每
次变更。SAMM 三级组织可以发布义务为 `Inconclusive` 的变更；
SAMM 一级组织可以发布义务为 `Pass` 的变更。判定是逐变更的，
不是逐组织的。

**mathcoding 拒绝什么：** "成熟的组织就是验证中的变更"这一假
设。成熟度是组织的属性；验证是变更的属性。两者是不同的种类。

**这是最近的保障成熟度近邻。** SAMM 与 mathcoding 共享保障
词汇。差异在于粒度：SAMM 是年度的、逐组织的；mathcoding 是
逐变更的、逐义务的。

## 20. NIST SSDF — 安全软件开发框架

NIST SSDF 是安全软件开发的实践框架：PO（准备组织）、PS（保护
软件）、PW（产出良好保护的软件）、RV（响应漏洞）。纪律是实
践；制品是 SSDF profile。

**mathcoding 继承了什么：** "实践即需求"的理念。mathcoding 决
策可以声明 `ssdf_practice`；义务是实践必须满足的属性。

**mathcoding 补充了什么：** SSDF 命名实践；mathcoding 把实践
绑定到验证器。符合 SSDF 但无验证器的实践是描述；同时命名实
践与验证器的 mathcoding 决策是检查。SSDF 是 profile；
mathcoding 是读取 profile 的闸门。

**mathcoding 拒绝什么：** "profile 就是验证"这一假设。profile
是描述；验证是逐变更的。mathcoding 用逐变更的义务取代
profile。

## mathcoding 继承的与补充的

mathcoding 并不是与先前工作的彻底割裂。它把已经存在的若干块
组合起来，并被以下三件其他方法论都不同时具备的属性所收紧：

| 来源 | mathcoding 继承了什么 |
|---|---|
| TDD | 测试作为证据 |
| BDD | 行为作为可被检查的声明 |
| DDD | 领域语言作为属性 |
| FDD | 特性作为规划单位 |
| MDD/MDA | 模型作为一级制品 |
| Spec-Driven Development | 规约作为真理之源 |
| ADR / MADR | 决策作为可版本化的制品 |
| arc42 | 节作为命名空间 |
| C4 Model | 缩放层级作为属性 |
| Living Documentation | 生成的制品作为证据 |
| Specification by Example | 示例作为见证 |
| OpenAPI | 机器可读契约 |
| Design by Contract | 前置/后置条件作为属性 |
| Formal Methods | 证明作为证据 |
| TOGAF | 阶段作为属性 |
| ISO/IEC/IEEE 42010 | 关注点作为属性 |
| Team Topologies | 认知负载作为摩擦的驱动 |
| SAFe | 节奏作为属性 |
| OWASP SAMM | 保障职能作为属性 |
| NIST SSDF | 实践作为需求 |

| mathcoding 补充的、且无其他方法论同时具备的内容 |
|---|
| 有限定的证据（主体、义务、输入、环境、摘要、方法、时间） |
| 诚实的不确定性（缺失 = Inconclusive，永不为 Pass） |
| 来源类别纪律（declared ≠ derived ≠ attested ≠ reviewed ≠ observed） |
| 判定状态纪律（Pass ≠ Fail ≠ Inconclusive ≠ InfrastructureError） |
| 五档风险 × 四级摩擦 |
| 反例要求（每条非微小的决策） |
| Waiver 状态机（Active、Grace、Expired、Revoked） |
| 受保护策略转换清单（7 道守卫） |
| 自应用（内核检查自身的升级） |
| 底层摘要（决策与证据在摘要相等时且仅当相同时相等） |

## mathcoding 拒绝什么

mathcoding 的拒绝不是特性；它是用以维持协议诚实性的边界：

- 没有观察的"已批准"。批准是 `Review` 证据；观察是
  `Observed` 证据；二者不可互换。
- 没有 `expires_at` 的 waiver。不会过期的 waiver 是许可
  条，不是延期。
- 缺失之上的 `Pass`。无证据的义务是 `Inconclusive`，不是
  `Pass`。"我没检查"不等于"我检查了，它工作"。
- 没有先前授权的受保护策略转换。候选策略不能为自己的采纳授
  权。
- 触及 `axioms/`、`constitution` 或 `kernel` 的变更，如果
  缺少反例、固件对与迁移路径。
- 没有 `risk.owner` 的决策。所有者是在义务失败时担责的人；
  没有所有者的决策是不可问责的。
- 名为 `unassigned`、`TBD`、`auto` 或 `system` 的补救。
  合成补救是占位符，不是补救。

## 何时 mathcoding 适用

适用包络（`spec/algebra-3.2.md` §28）以敌对的方式写就：哪些
项目*无法承担*这一纪律。更友善的读法反过来问：哪些项目从中
获益？纪律的真实成本是多少？

诚实的答案是：纪律很便宜。在变更之前写一个 `commitment:` 和
一个 `obligation:` 块只需几秒，并非几小时。内核对通过的变更
的判定耗时不到一秒。mathcoding 的成本主要花在 *思维的清晰*
上，而非 *流程的仪式* 上 —— 而思维的清晰在所有项目中（包括最
小的项目）都有回报。

小型项目的成功通常在第一个小时内就被决定：问题越好，代码越
好。mathcoding 的纪律本质上就是在写代码之前先把问题写下来。
这对于在黑客松上的单个开发者有用，对于在受监管的航空航天系
统上的五十位开发者也有用。

纪律回报最高的地方，其成本不可见：

| 信号 | 为什么 mathcoding 有帮助 |
|---|---|
| 单独开发，无审计，1 年生命期 | 强迫你在写代码之前先把问题写下来；成本极低（每次变更数秒） |
| 黑客松、MVP、原型 | 强迫你说明原型应当证明什么；按名避免过度工程 |
| 1 人团队 + AI 编程代理 | 强迫你在代理写代码之前先声明契约；把"vibe coding"变成"spec coding" |
| 两个或更多 AI 代理同时编辑同一仓库 | 强迫每个代理声明自己的承诺；防止静默覆写 |
| 5 年以上生命期，3 人以上团队 | 强迫架构决策比其作者活得更久；记录就是救生计划 |
| 监管或合同审计要求 | 证据存储与阻塞闸门本身就是审计追踪 |

mathcoding 真正构成开销的，只有内核已以静默模式覆盖的那些场
景：对注释的 30 秒拼写修正（模式 `tiny`；内核静默；纪律不可
见）、对固件的单行补丁（模式 `light`；一行 `commitment:` 块）、
对生产故障的紧急 hotfix（请用 waiver 路径；事后决策在 24 小时
内强制完成）。

在其他所有情况下 —— 包括"我只是一个人，并且我明天就会把这
东西扔掉"——"在写代码之前先把问题写下来"这一纪律就值它所花
的那几秒。

关于成本的诚实参考：
`mathc time-estimate --class single-file-edit --count 1 --percentile p50`
—— 一个单文件决策的完整挂钟时间约 3 分钟。其中大部分时间是
*思考*，不是 *打字*；纪律让思考显式化，这正是它的意义所在。

## 延伸阅读

- [方法论](methodology.html) —— 纪律。
- [公理](axioms.html) —— 五条公理。
- [基石](foundations.html) —— 公理 → OCaml。
- [规范/宪法](constitution.html) —— 14 条不变量。
- [规范/algebra-3.2](../spec/algebra-3.2.html) —— 形式化代数
  （规范性的）。
- [USAGE](../USAGE.html) —— 路径 A / 路径 B 的采用手册。
