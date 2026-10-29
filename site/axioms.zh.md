# 公理

> math-coding 的五条规范性公理。每条公理都是对内核**能
> 否断言**内容的约束，而不是内核交付的特性。完整表述位于
> `axioms/`；本页是其散文式摘要。

## A0 — 分离

<figure class="mathc-axiom-figure">
<img src="assets/axiom-separation.svg" alt="公理 A0 — 分离：种类彼此不同，链条单向流动。">
</figure>

种类彼此不同；链条单向流动。

存在以下种类的对象：

```text
intent, decision, obligation, change, attestation, observation, revision
```

任意两者都不是同一个对象。意图不是决策。决策不是义务。
变更不是证据。链条只单向流动。修订不会回到决策；它要么
取代，要么不取代，由显式字段 `Decision.supersedes` 决定。

## A1 — 反馈

<figure class="mathc-axiom-figure">
<img src="assets/axiom-feedback.svg" alt="公理 A1 — 反馈：每项承诺都存在通向观察的路径。">
</figure>

每项承诺都存在通向观察的路径。

系统中的每项承诺，都存在一条路径，让外部世界告诉系统
该承诺是否成立。该路径为：`承诺 -> 预测 -> 观察 -> 修订`。
如果没有观察，承诺就只是愿望。

## A2 — 不变量与恢复

<figure class="mathc-axiom-figure">
<img src="assets/axiom-invariants.svg" alt="公理 A2 — 不变量与恢复：每条不变量都配有恢复路径。">
</figure>

每条不变量都配有恢复路径。

对于每条不变量 `I`，都存在一个恢复算子 `R`，使得当 `I`
不成立时，系统会以已授权的补救措施报告缺口。当现有负责
人能够执行该补救措施时，即视为已授权。一项阻塞性决策若
未指明补救措施，则其本身就是一个缺口。

## A3 — 自应用

<figure class="mathc-axiom-figure">
<img src="assets/axiom-self-application.svg" alt="公理 A3 — 自应用：规则管理自身的变更。">
</figure>

规则管理自身的变更。

对于每个迁移 `(K_n, P_n) -> (K_{n+1}, P_{n+1})`，该
迁移满足：

```text
Gate_{K_n, P_n}(transition) = Open
Conformance(K_{n+1}) = Pass
Migration(K_n, K_{n+1}) = Pass
VerdictDiff(K_n, K_{n+1}) subset DeclaredSemanticChanges
SelfVerify(K_{n+1}, P_{n+1}) = Pass
```

尤其是：`P_{n+1}` 不得参与自身通过过程的授权。候选策略
不能授权自身通过。

## A4 — 关怀

<figure class="mathc-axiom-figure">
<img src="assets/axiom-care.svg" alt="公理 A4 — 关怀：负责人、后果、问责、到期。">
</figure>

负责人、后果、问责、到期。

对每项承诺、决策、义务、证据或豁免，系统都会指明：

```text
若其成立，谁受益
若其失败，谁受损
谁对此负责
何时将重新审视
```

这四项不可议价。它们是*关怀一个结果*的最低内容。

## 内核如何强制执行这些公理

| 公理 | 内核机制 |
|------|----------|
| A0 | `lib/domain.ml` 中种类标签使用封闭变体；按种类的前缀摘要；JSON Schema 中关闭 `additionalProperties` |
| A1 | `result` 枚举包含 `Inconclusive` 和 `InfrastructureError`，与 `Pass` 区分；豁免附带 `expires_at`；操作结果允许 `absence_means: inconclusive` |
| A2 | 闸门变体包含 `Blocked` 并带 `remedies`；诊断信息包含 `next_actions`；退出码 `0/1/2/3` 遵循 `OCAML_KERNEL_CONVENTIONS.md §4.3` |
| A3 | `decisions/decision.yaml` 中的活动策略引用此索引；宪法变更需要迁移与一致性；旧策略授权新策略 |
| A4 | `decision.risk.owner`、`obligation.decision`、`assumption.owner`、`waiver.issuer`、`attestation.producer_identity` 为必填项，而非可选项 |

v3.0.0.20 的完整强制执行周期参见
[methodology](methodology.html)。
