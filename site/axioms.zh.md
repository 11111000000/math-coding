# 公理

> math-coding 的五条规范性公理。每条公理都是对内核**能
> 否断言**内容的约束，而不是内核交付的特性。完整表述位于
> `axioms/`；本页是其散文式摘要。

## 五条公理

每条公理都是对内核**能否断言**内容的约束，而不是内核交付的
特性。规范性表述就是 `axioms/` 目录下的文件；本页只给出指向
它们的链接。

| ID | 标题 | 表述 |
|----|------|------|
| A0 | 分离 | [axioms/separation.md](axioms/separation.html) |
| A1 | 反馈 | [axioms/feedback.md](axioms/feedback.html) |
| A2 | 不变量与恢复 | [axioms/invariants.md](axioms/invariants.html) |
| A3 | 自我适用 | [axioms/self-application.md](axioms/self-application.html) |
| A4 | 关怀 | [axioms/care.md](axioms/care.html) |

## 内核如何强制执行这些公理

表格只有一张，而且是规范性的：`axioms/index.md` 将每条公理
映射到强制执行它的内核机制。

完整的强制执行周期参见
[methodology](methodology.html)。
