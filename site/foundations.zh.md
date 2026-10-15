# 基础

> **从公理到 OCaml。** 每个基础是 `decisions/` 下的一个
> 包，将一条公理映射到内核机制和验证义务。五条公理与
> 从 v3.0.0.19 起闸控仓库的五个 bootstrap 决策相对应：

![左侧为五条公理，右侧为它们强制执行的 bootstrap 决策：A0 Separation -> bootstrap-v3，A1 Feedback -> attestation-store-fill，A2 Invariants -> kernel-conformance-runner，A3 Self-application -> mathc-self-check-subcommand，A4 Care -> validate-and-context。页脚："每条公理都由内核检查的具体决策落地；公理不是宣言。"](assets/axiom-graph.svg)

上述图示的每一行对应以下五个章节之一。图示即规范；
以下章节为实现。

## A0 — 分离 → `bootstrap-v3`

**公理。** 种类彼此不同；链条单向流动。
`意图 ≠ 决策 ≠ 义务 ≠ 变更 ≠ 证据 ≠ 观察 ≠ 修订`。

**机制。** `lib/domain.ml` 中为每种类型使用封闭变体；
每个文档使用前缀提示；`schemas/` 下的 JSON Schema 使用
封闭的 `additionalProperties`。解析器拒绝任何 id 不属于
相应 schema 中声明的封闭集合的文档。

**验证。** `decisions/mathc-packages-subcommand.yaml`
中的 `packages-kernel-walker` 义务枚举仓库中的每个
决策，并产出类型化的缩合；遍历器在遇到不属于封闭
集合的种类时崩溃。

A0 图示（如上方公理图所示）本身就是 A0 的一次实践：
每条公理和每个决策都是不同的种类。图示不是协议的
流程图，而是约束的出处图。

## A1 — 反馈 → `attestation-store-fill`

**公理。** 每项承诺都有通往观察的路径：
`承诺 → 预测 → 观察 → 修订`。没有观察，承诺只是愿望。

**机制。** `attestations/*.json` 将每个决策-义务对记录为
`pass | fail | stale | unknown | missing | no_store` 之一。
`lib/attestations.ml` 加载存储并将其每条记录与内核闸门
进行连接。

**验证。** `scripts/generate-attestations.py` 在每次发布时
生成 94 个证据文件；`mathc gate BASE HEAD` 报告
`gate-pass.t` / `gate-fail.t` / `gate-stale.t` 为绿色
（cram 装置在 `tests/cli/` 下）。

证据生命周期图示（绘制在本页底部）展示了将 CI 运行
转化为判定的五个阶段：production 捕获底物指纹，store
写入证据文档，join 将条目与义务配对，verdict 将各义务
结果合成为单一裁定，而 expiry 在达到 `valid_until` 时
将义务翻转为 `Inconclusive`。A1 公理说每个承诺都有这样
的路径；生命周期就是该路径。

## A2 — 不变量与恢复 → `kernel-conformance-runner`

**公理。** 对于每个不变量 `I`，存在被授权的恢复算子
`R`。修复方案是有限的。

**机制。** `lib/gate.ml` 将每个义务与证据存储求值，并产出
具有 `causes` 与 `remedies` 的类型化 `Gate.gap` 记录。
内核绝不会在未指明修复方案的情况下阻塞合并。

**验证。** `tests/conformance.ml` 枚举每个装置并断言运行
器不会崩溃；在干净的 `main` HEAD 上 `mathc self-check`
返回 `pass`。

`kernel-conformance-runner` 决策将 A2 绑定到
`tests/conformance.ml` 可执行文件。conformance 语料中的
每个装置都与 `lib/diagnostic.ml::explain` 中相应的
`mc-*` 类型码配对。如果运行器崩溃，缺口消息将命名运行
器预期消费的注册表项——这是一次类型化的点名，而不是
堆栈回溯。

## A3 — 自应用 → `mathc-self-check-subcommand`

**公理。** 规则管理自身的变更：
`(K_n, P_n) → (K_{n+1}, P_{n+1})` 要求 Gate Open、
Conformance Pass、Migration 往返通过、VerdictDiff 落在
DeclaredSemanticChanges 内、SelfVerify Pass。

**机制。** `mathc self-check` 遍历 `decisions/` 中的每个
决策，并产出 JSON 判定，其中指明产生该判定的内核
（可执行文件的 SHA-256）和仓库摘要。判定按**当前**
规则闸控，在锁被提升之前。

![A3 自应用：(内核, 策略) 对是其自身的闸门。两个状态 (K_n, P_n) 和 (K_{n+1}, P_{n+1}) 通过转移连接。守卫条件：Gate = Open，Conformance = Pass，Migration = Pass，VerdictDiff ⊂ DeclaredSemanticChanges，SelfVerify = Pass。](assets/a3-self-application-flow.svg)

上图是 A3 公理的可视化。A3 表明内核必须检查自身的
升级路径：闸控 `(K_n, P_n) → (K_{n+1}, P_{n+1})` 的规则
与闸控任何其他转移的规则相同。图中的五个守卫是内核
在发布新版前对其自身强制执行的前置条件。

**验证。** `tests/cli/self-check-{pass,fail,unknown}.t`
为绿；`decisions/mathc-self-check-subcommand.yaml` 中
的义务 `mathc-self-check-dispatcher-shipped` 已满足。

## A4 — 关怀 → `validate-and-context`

**公理。** 对于每项承诺：谁受益、谁受损、谁负责、何时
回顾。

**机制。** `decision.risk.owner`、`obligation.decision`、
`assumption.owner`、`waiver.issuer`、
`attestation.producer_identity` 在各自的模式中是
**必填**字段。解析器拒绝没有负责人的决策。

**验证。** `fixtures/conformance/decision/negative-*.yaml`
因缺少必填字段而被 `Decision.parse_decision` 拒绝；
`fixtures/conformance/decision/positive-*.yaml` 被接受。

A4 是将其余四条公理与人联系起来的公理。A0、A1、A2
和 A3 都是结构性的——它们描述内核如何移动字节。
A4 表明内核存在是因为人有所关怀，而有所关怀的人
承担问责。`validate-and-context` 决策命名了模式中的
四个必填字段；没有它们，内核拒绝该制品。

## 扩展

三个扩展在不改变五项基础的前提下增加了内核表面：

| 扩展 | 表面 | Cram 装置 |
|------|------|-----------|
| `mathc-explain-subcommand` | `mathc explain decision:foo` → `{kind,id,digest,path,body}` | `explain-{positive,negative}.t` |
| `mathc-self-check-subcommand` | `mathc self-check` → JSON 判定 | `self-check-{pass,fail,unknown}.t` |
| `mathc-packages-subcommand` | `mathc packages --format=text\|json\|html` → 包列表 | `packages.t` |

v3.3.0 版的内核在其之上提供了 3.2-理想代数。站点的
[Packages](packages.html) 页是每个活跃决策的实时判定；
当前构建报告 93 个活跃决策 / 330 项义务（313 pass /
16 missing / 1 unknown）。

## 支撑图示

下图是网站其余部分使用的视觉词汇。每个图都使用相同的
Tufte 调色板绘制，使协议已发布的表面在各页面间保持
一致。

![证据生命周期：production、store、join、verdict、expiry。从 CI 运行到闸门判定的五个阶段。](assets/attestation-lifecycle.svg)

证据生命周期是 A1 的具体形态：每个承诺都有通往观察
的路径，且路径为 production → store → join → verdict →
expiry。五个阶段恰好是 `attestation-store-fill` 决策的
五行；图示是决策运行起来的样子。

![反例流程：作者在 decision.yaml 中写入反例集合；内核对任何 mode 非 tiny 的决策检查 |C(D)| >= 1；若缺失，闸门阻塞合并并产出修复。反例是可机器检查的强制函数；对立面是作者接触过的连贯反方立场（algebra section 11, 11.1）。](assets/counterexample-flow.svg)

反例流程是辩证方法中 `counterexample` 槽的具体形态。
A1 表明每个承诺都必须有通往观察的路径；反例槽是作者
在内核发布决策之前提供的路径。

![公理转移：re_evaluate(d, A_new) 神谕返回三个 ReEvaluationStatus 值之一——Compatible、Inconclusive、StaleClaim——闸门判定为 impact-list 上的 max_verdict（algebra section 17）。](assets/axiom-transition.svg)

公理转移流程是 `re-evaluate-decisions` 义务的具体形态。
A3 表明规则管理自身的变更；`re-evaluate(d, A_new)` 是
内核在采纳规则变更之前对其进行测试的机制。

![信任动态：说谎者悖论在单跳内可解——节点只信任自身的观察和下一个节点的观察，从不信任下一个节点的声明；系统是可靠的，因为声明只通过已被观察的声明传播，而已被观察的声明依定义为诚实。](assets/trust-dynamics.svg)

信任动态图是 A1 的底层图论。每个节点只信任自己的观察
和下一个节点的观察；声明仅通过已被观察的声明传播。
A1 是公理；信任动态图是满足它的图。

![底物指纹：内核将底物（决策存储、证据存储、活跃策略）
合成为一个 sha256，即 fingerprint。两个底物在 A0 下等价
当且仅当它们的 fingerprint 匹配；内核不会以除 fingerprint
相等之外的任何方式来处理"它们是否相同"的问题。](assets/substrate-fingerprint.svg)

底物指纹图是 A0 的形式对应物。种类彼此不同；底物的
身份是将其与任何其他底物区分开的 fingerprint。两个
底物在 A0 下等价，当且仅当它们的 fingerprint 匹配。

![豁免状态机：豁免 FSM 有四个状态——Active、Grace、Expired、Revoked——和三个转移。豁免在达到其 valid_until 时进入 Grace；豁免在 grace 耗尽时进入 Expired；豁免在签发人撤销时进入 Revoked。被豁免修改的决策在 Grace 和 Expired 期间保持为 StaleClaim，内核拒绝闸控任何在这些状态下依赖它的制品。](assets/waiver-state-machine.svg)

豁免状态机是 `waiver-infrastructure-2026-10` 决策的
具体形态。豁免是某个人关于义务不适用于特定变更的声明；
FSM 记录豁免的生命周期，内核拒绝闸控任何依赖处于非
Active 状态的豁免的制品。

![摩擦包络：风险（X 轴）对变更代码行数（Y 轴），
针对摩擦阶梯的四级。silent 包络最小，block 最大。
mode 是上限：变更的 mode 是包含其位置的最小的包络。
对于错别字修正，包络很小；对于模式变更，包络很大；
内核选择与包络匹配的摩擦级别。](assets/friction-envelope-plot.svg)

摩擦包络图是 `risk` 函数的几何形态。mode 是包含变更
`(risk, lines_changed)` 位置的最小的包络；摩擦级别是
其包络与变更的 mode 相匹配的阶梯。错别字修正位于
silent 包络内；模式变更位于 block 包络内。

![质量雷达：衡量变更质量的六个轴（correctness、scope、alignment、attestation、recovery、cost）。每个轴从 0 到 1；内核每次闸门运行为每条轴产出一个评分。当所有六个均高于策略声明的底线时，变更是可接受的；底线显示为六边形。雷达图将底线叠加在当前评分之上，让审阅者一眼看出哪些轴低于阈值。](assets/quality-radar.svg)

质量雷达是 `change-quality` 义务的可视化。每个轴是变更
质量的不同方面；底线由策略设定。想要了解变更为何被
拒绝的审阅者可以阅读雷达图，看哪条轴低于底线。

![三个独立的时间报告尺度：wall-clock-minutes、token-budget、step-count。三个尺度可独立观察，不得合并为单一自然语言估计（AGENTS.md section Honest time reporting；algebra section 18）。](assets/reasoning-budget.svg)

推理预算图强制执行项目诚实报告时间的规则。三个尺度
（wall-clock 分钟、token budget、step count）可独立
观察；内核报告全部三个，并拒绝将它们合并为单一自然
语言估计。该图将三个尺度显示为独立的坐标轴；想要
了解一项变更"花了多少时间"的审阅者必须阅读全部
三个。
