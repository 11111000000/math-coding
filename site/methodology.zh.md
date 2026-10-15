# 方法论 — mathcoding

> 本页介绍 math-coding（内核）所实现的方法论。我们将这
> 种方法论称为 **mathcoding** —— 作为应用于软件变更的学科
> 而存在的 math-coding。内核是参照实现；方法论是思考
> 方式。

## mathcoding 是什么

Mathcoding 是在每一次合并之前，将每一个有意义的变更与
**可观察的承诺**绑定的实践。它不是 CI 工具，不是代码
审查工具，也不是文档工具。它是把意图、决策、义务、变更、
证据与修订串联为同一条链的学科：

![math-coding 链：意图、决策、义务、变更、证据、修订。义务被高亮——内核的检查就位于此处。一段褐红色的虚线弧从修订绕回意图，标注为"修订将承诺延展到下一个决策"。](assets/chain.svg)

链条由内核强制。内核不会向链条中写入新的内容——它
只是 *检查* 人们所写的内容是否诚实。（A0 分离：证据
不是观察；决策不是义务；变更尚未被认证。）内核产出
判定（`pass`、`fail`、`unknown`、`waived`、`stale`、
`missing`）；行动者依然是人。

图中所展示的七种类不是层级，而是一份契约。每一类都是
具有独立目的的独立对象：

- **意图（intent）** 是某人想要做的事情。
- **决策（decision）** 是为做这件事而记录的承诺。
- **义务（obligation）** 是内核可以对变更进行检查的属性。
- **变更（change）** 是落到 main 的 diff。
- **证据（attestation）** 是义务被满足的证据。
- **观察（observation）** 是世界对义务是否被满足的信号。
- **修订（revision）** 是关于下一步该做什么的已记录决定。

图中从 `修订` 折回 `意图` 的褐红色虚线弧即闭合性
性质：修订将承诺延展到下一个决策，因此链条没有起点。
（A3 自应用：规则管理自身的变更——包括本图本身。）

## 五条公理

方法论建立于五个命题之上。每一条都是对内核"能说什么"
的约束，而不是内核交付的特性。

| ID | 标题 | 一句话 |
|----|------|--------|
| A0 | 分离 | 种类彼此不同；链条单向流动 |
| A1 | 反馈 | 每个承诺都有通往观察的路径 |
| A2 | 不变量 | 每个不变量与一条恢复路径配对 |
| A3 | 自应用 | 规则管理自身的变更 |
| A4 | 关怀 | 需要负责人、后果与问责 |

公理以 Markdown 形式存放在 `axioms/` 中。内核只把它们
当作数据读取，而不是指令。形式化陈述请参见
[axioms](axioms.html)。每条公理由一项特定的 bootstrap
相关决策落地：

![左侧为五条公理，右侧为它们强制执行的 bootstrap 决策：A0 Separation -> bootstrap-v3，A1 Feedback -> attestation-store-fill，A2 Invariants -> kernel-conformance-runner，A3 Self-application -> mathc-self-check-subcommand，A4 Care -> validate-and-context。页脚："每条公理都由内核检查的具体决策落地；公理不是宣言。"](assets/axiom-graph.svg)

图的右列是 bootstrap 闸门所验证的决策列表。配对是
穷尽的（A0 到 A4 各对应一项特定决策），这一事实使得公理
是"可操作的"而非"宣言性的"。

## 实践中的工作链

变更以 `git diff` 形式到达。内核提出四个问题：

1. **模式。** 每个制品（决策、义务、证据、豁免）是否
   与其 JSON 模式匹配？（`mathc validate`。）
2. **身份。** 每个关系端点是否可解？每个 `(kind, id,
   revision)` 是否构成全局唯一三元组？（章程不变量 2
   和 4。）
3. **新鲜度。** 证据是否仍然有效？是否有任何素材摘要
发生变化？（`mathc gate BASE HEAD`。）
4. **覆盖度。** 活跃策略中声明的每项义务是否至少拥有
   一个机器可校验的验证器以及一组正向+负向装置？
   （`mathc self-check`。）

这四个问题各对应 verdict-flow 流水线中的一步。下方
所示的流程与每次调用 `mathc gate` 或 `mathc self-check`
时运行的代码路径相同：

![判定流程：从 decision.yaml 与证据到 gate_merge 与导出到代码。决策经身份 I4 解析；按 spec/algebra-3.2 §8 推导义务；按 §2 的风险函数分类 mode；按 §9 组合直接与传递义务；按 §14 跨运行中的 CI 收集证据；按 §15 的 gate_merge 以及 A2 不变量。输出行列出 spec/semantics.md §4.3 中的四种判定颜色与代码。](assets/verdict-flow.svg)

流水线从两个输入读取——决策存储与证据存储——并产生
一个输出——按义务的判然，之后合成为带退出码的单一裁定。
中间三个步骤（推导、分类、组合）是内核能做到的部分：从
异构的证据中合成出部分真值，形成单一可辩护的判定——
这是任何 CI 工具所不能做到的。

第四个问题是关闭 **bootstrap 闸门** 的那个问题。
bootstrap 闸门的 `pass` 意味着已发布的内核能够成功
检查本仓库及其 conformance 语料。从那次发布开始，内核
的判定成为自动化保证，而非人工宣言。

## 摩擦级别

Mathcoding 并不统一。有些变更属于 silent（确定性检查
确认未发生有意义的变化）；有些需要记录 record（决策 +
义务）；有些需要 *ask*（必须有审查者介入）；有些会
**block**（内核拒绝合并）。阶梯为：

```text
silent < record < ask < block
```

内核选择最低充分级别。内核可以提高摩擦，但绝不会降低。

![摩擦阶梯：silent（顶层，内核选择）之下 ask（人工审阅）之下 block（底层，内核拒绝）。四级阶梯配有摩擦包络、代表性的代提交类型、闸门姿态以及 AGENTS.md friction ladder 与 A3 self-application 要求的签署人。](assets/friction-ladder.svg)

摩擦阶梯有一条横向轴（摩擦包络）与一条纵向轴（介入
级别）。请注意四级与四条风险带之间的对齐：

![风险带：五条彩色带，从 tiny 到 exhaustive，分别映射到示例变更、闸门姿态以及签署人。带：tiny（浅灰）、light（浅米）、standard（浅褐红）、strict（更深的褐红）、exhaustive（纯褐红）。](assets/risk-bands.svg)

用于对变更进行分类的风险函数与将其映射到摩擦级别的
函数是同一个（参见 `spec/algebra-3.2.md` §2 与 §21）。
一项变更若风险足以被分类为 `exhaustive`，则必为
`block`；若被分类为 `tiny`，则必为 `silent`。两幅图是
对同一性质的两种视图。

四条风险带不仅为变更贴上标签——它们将闸门姿态
（silent / record / ask / block）绑定到已签名的证据
类型。`strict` 带要求审查者签名加上自动化证据。
`exhaustive` 带要求发布工程师签名加上 conformance-runner
证据。内核从不捏造这些要求；策略在
`decisions/decision.yaml` 中声明它们。

## 采用

在既有项目中采用 mathcoding，实际只需三步：

1. 创建 `decisions/decision.yaml`，声明活跃策略
   （从 `bootstrap-v3@2` 开始）。
2. 将内核二进制（`mathc`）加入 CI；`mathc self-check`
   成为阻塞步骤。
3. 将既有保障——代码审查记录、JUnit 报告、安全证据——
   移入 `attestations/` 目录的 JSON 中。内核读取它们；
   内核不会对它们说谎。

第三步才是改变项目文化的那一步。代码审查评论是项目
中的人类之声；`attestations/*.json` 中的证据是机器
之声。内核读取机器之声并产出判定；人读取人类之声并
产出修订。两种声音必须达成一致。本站中有一份已完成的
示例。仓库中的 README、ROADMAP、PACKAGES 与 AGENTS 文件
本身也是方法论的输入。

证据生命周期是内核与 CI 之间的契约：

![证据生命周期：production、store、join、verdict、expiry。从 CI 运行到闸门判定的五个阶段。production 在一次 CI 运行内捕获底物指纹。store 写入证据文档。join 读取存储并将证据与义务配对。verdict 将各义务结果合成为单一裁定。expiry 在达到 valid_until 时将义务翻转为 Inconclusive。](assets/attestation-lifecycle.svg)

五个阶段——production、store、join、verdict、expiry——
覆盖了内核读取的每一次 CI 运行。"expiry" 阶段是大多数
项目所遗漏的：即便代码中没有任何变更，义务也可能仅因
时间推移而过期。每项义务上的 `valid_until` 字段使得
判定在时间维度上也是诚实的，而不仅仅在提交那一刻。

## 为什么这是方法论，而非工具

工具运行在计算机上。方法论检查计算机（以及使用它的
人）是否在做他们说过要做的事。math-coding 内核是
方法论的参照实现；方法论是内核所强制实施的约束集合。
没有方法论，内核只是一个对格式良好的 JSON 产出判定的
解析器。没有内核，方法论是一种不产生强制保证的学科。

两者按序存在。方法论约束内核。内核证明方法论。这
就是 A3 中 *自应用* 的含义：规则管理自身的变更。

![math-coding 内核流水线：input -> schema -> parser -> attestation join -> self-check -> gate。每个阶段产出下一阶段消费的制品。内核不捏造内容；它只是检查人们所写的内容是否诚实。](assets/kernel-architecture.svg)

上面的流水线就是架构。图中的每个方框都是内核的一个
模块。每条箭头都是一次函数调用。内核小到可以在半天内
审计完（它是一个约七千行 OCaml 代码加上传递模块组成的
二进制）。方法论则相反——它是作为人，决定如何处理内核
判定的那件事；而 A4 要求的，正是以关怀做出这一决定。
