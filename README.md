# 混凝土搅拌站 · 生产调度与罐车管理

以「生产任务单」为核心的搅拌站生产调度全栈演示项目。

## 技术栈

- 后端：Spring Boot 3.3.0 + Java 17 + Spring Data JPA(Hibernate 6.5) + MySQL 8 + Redis
- 前端：Vue 3 + Element Plus + Vite

## 端口

| 服务 | 端口 |
| --- | --- |
| 前端 | 8281 |
| 后端 | 8381 |
| MySQL | 3581 |
| Redis | 6581 |

## 启动

```sh
./start.sh      # 首次或 --build 会构建镜像，之后秒起
./stop.sh       # 暂停
./resume.sh     # 恢复
./clean.sh      # 收摊（删容器 + 匿名卷）
```

## 模块（按生产流程串起来）

1. **任务** — 搅拌楼与主机台账：主机产能负载竖条（完成方量 / 当日计划方量，超计划变红），点竖条右侧滑出抽屉派发任务单。
2. **配料** — 生产任务单配合比卡：强度等级徽章 + 环形占比图（conic-gradient），就地改每方用量，自动重算水胶比并校验上限。
3. **出厂** — 罐车发车排队轨道：胶囊按排队顺序排列，HTML5 原生拖拽换序，点胶囊推进「装车 → 出厂 → 到工地 → 签收」。
4. **签收** — 原材料筒仓液位柱 + 补料申请审批：低于安全库存闪烁告警，通过审批后回补库存。

## 数据访问要点

- 「生产任务单」是聚合根，`@OneToMany(mappedBy = "order", cascade = ALL, orphanRemoval = true)` 双向挂配合比明细行；
  明细行没有独立的新增 / 修改接口，只能通过 `/api/orders/{id}/items` 在聚合根内调整。
- 实体与集合上标注 `@BatchSize(size = 50)` 抑制 N+1。
- 手写 JPQL：`按强度等级统计方量`、`按工地汇总发货量`、`按日期查生产台账`、`主机产能负载`、`低库存筒仓`、`同主机时段重叠校验`。
- 业务规则（抛 `BizException`）：同一主机时段不可重复排产、发车时罐车必须是「待命」、签收方量不得超过装车方量、开工前校验筒仓库存并给出具体缺料吨数。
- 临时故障停机先由 `/api/fault-shutdown/preview` 只读预演：仅纳入待排产且无发车记录的任务；生产中、已完成或已有发车记录的任务逐项列明不可改派。确认时重新核对阶段、发车记录和接替主机排期，在单事务内置主机故障、保存处置记录并整批改派，任一冲突或条件变化全部回滚。

## 主要接口

```
GET  /api/plants                     搅拌楼
GET  /api/mixers/load                主机产能负载
POST /api/fault-shutdown/preview     临时故障停机与改派预演（只读）
POST /api/fault-shutdown/confirm     确认故障停机并整批改派（单事务）
GET  /api/orders                     任务单列表
POST /api/orders                     新建任务单
PUT  /api/orders/{id}/items          调整配合比（重算水胶比）
POST /api/orders/{id}/start          开工（校验筒仓库存）
GET  /api/trucks                     罐车排队
PUT  /api/trucks/reorder             拖拽换序
POST /api/dispatch                   发车装车
POST /api/dispatch/{id}/advance      状态推进 depart/arrive/sign
GET  /api/silos                      筒仓液位
POST /api/replenish                  补料申请
POST /api/replenish/{id}/approve     审批通过
GET  /api/stats/dashboard            看板总览（Redis 缓存 30s）
```
