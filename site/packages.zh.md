# 包

math-coding 3.3.0。每一行
> 都是内核所知的一个决策-义务对；每条判定都是内核当前的
> 评估。

下方的包网格是下列命令的实时输出：

```bash
mathc packages --format=html
```

内核以 JSON（`--format=json`）和定宽表（`--format=text`）
输出相同的数据。HTML 形式带有 `data-mathc-package-count`
属性，使站点级工具可在不重走决策的情况下校验内核给出的
计数。

## 为何需要包表面

项目的保障态势是由决策-义务对组成的图。遍历该图是内核的
职责；**发布**该图则是包表面的职责。若没有它，每个消费者
（站点、LLM 代理、下游 CI）都必须重新遍历 `decisions/*.yaml`
并复现同一份解析。有了该表面，每个消费者读取的是同一份
内核输出。

## 如何消费

```bash
mathc packages --format=json | jq '.counts'
```

给出实时聚合：

```text
{
  "fail": 0,
  "missing": 0,
  "no_store": 0,
  "pass": 23,
  "stale": 0,
  "total": 23,
  "unknown": 0,
  "waived": 0
}
```

正文下方的网格即为 HTML 形式，由 `lib/render/render.ml` 内嵌。
内核同时写入两种形式。
