-- 混凝土搅拌站 · 生产调度与罐车管理
-- ddl-auto=none，表结构与种子数据全部在这里建好（mysql/Dockerfile 在构建期执行本文件）
SET NAMES utf8mb4;

-- ========================= 建表 =========================
DROP TABLE IF EXISTS recheck_task;
DROP TABLE IF EXISTS test_item;
DROP TABLE IF EXISTS sample_group;
DROP TABLE IF EXISTS fault_reassignment;
DROP TABLE IF EXISTS fault_shutdown_record;
DROP TABLE IF EXISTS replenish_request;
DROP TABLE IF EXISTS dispatch_ticket;
DROP TABLE IF EXISTS mix_ratio_item;
DROP TABLE IF EXISTS production_order;
DROP TABLE IF EXISTS silo;
DROP TABLE IF EXISTS truck;
DROP TABLE IF EXISTS mixer;
DROP TABLE IF EXISTS mixing_plant;

-- 搅拌楼
CREATE TABLE mixing_plant (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    plant_code  VARCHAR(32)  NOT NULL COMMENT '楼号编码',
    name        VARCHAR(64)  NOT NULL COMMENT '搅拌楼名称',
    line_count  INT          NULL COMMENT '生产线数量',
    location    VARCHAR(128) NULL COMMENT '所在区域',
    PRIMARY KEY (id),
    UNIQUE KEY uk_plant_code (plant_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='搅拌楼';

-- 搅拌主机
CREATE TABLE mixer (
    id                   BIGINT        NOT NULL AUTO_INCREMENT,
    mixer_code           VARCHAR(32)   NOT NULL COMMENT '主机编码',
    name                 VARCHAR(64)   NOT NULL COMMENT '主机名称',
    model                VARCHAR(32)   NULL COMMENT '型号 HZS120/HZS180',
    theoretical_capacity DECIMAL(8,2)  NULL COMMENT '理论产能 m³/h',
    daily_plan_volume    DECIMAL(10,2) NULL COMMENT '当日计划方量 m³',
    status               VARCHAR(16)   NOT NULL COMMENT 'RUNNING/IDLE/MAINTENANCE/FAULT',
    plant_id             BIGINT        NULL COMMENT '所属搅拌楼',
    PRIMARY KEY (id),
    UNIQUE KEY uk_mixer_code (mixer_code),
    KEY idx_mixer_plant (plant_id),
    CONSTRAINT fk_mixer_plant FOREIGN KEY (plant_id) REFERENCES mixing_plant (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='搅拌主机';

-- 生产任务单（聚合根）
CREATE TABLE production_order (
    id                 BIGINT        NOT NULL AUTO_INCREMENT,
    order_no           VARCHAR(32)   NOT NULL COMMENT '任务单号',
    project_name       VARCHAR(128)  NOT NULL COMMENT '工程名称',
    contractor         VARCHAR(128)  NULL COMMENT '施工单位',
    pour_part          VARCHAR(128)  NULL COMMENT '浇筑部位',
    strength_grade     VARCHAR(8)    NOT NULL COMMENT '强度等级 C25/C30/C35/C40',
    planned_volume     DECIMAL(10,2) NOT NULL COMMENT '计划方量 m³',
    slump              VARCHAR(32)   NULL COMMENT '坍落度要求',
    status             VARCHAR(16)   NOT NULL COMMENT 'PENDING/PRODUCING/DONE',
    planned_start      DATETIME      NULL COMMENT '计划开始',
    planned_end        DATETIME      NULL COMMENT '计划结束',
    water_binder_ratio DECIMAL(5,3)  NULL COMMENT '水胶比',
    remark             VARCHAR(255)  NULL,
    mixer_id           BIGINT        NULL COMMENT '排产主机',
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_no (order_no),
    KEY idx_order_mixer (mixer_id),
    KEY idx_order_status (status),
    CONSTRAINT fk_order_mixer FOREIGN KEY (mixer_id) REFERENCES mixer (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='生产任务单';

-- 配合比明细（任务单子行，只能通过任务单维护）
CREATE TABLE mix_ratio_item (
    id            BIGINT        NOT NULL AUTO_INCREMENT,
    order_id      BIGINT        NOT NULL COMMENT '所属任务单',
    material_code VARCHAR(16)   NOT NULL COMMENT '材料编码',
    material_name VARCHAR(64)   NULL COMMENT '材料名称',
    dosage        DECIMAL(10,2) NOT NULL COMMENT '每方用量 kg/m³',
    ratio_percent DECIMAL(6,2)  NULL COMMENT '占每方总用量百分比',
    seq           INT           NULL COMMENT '展示顺序',
    PRIMARY KEY (id),
    KEY idx_item_order (order_id),
    CONSTRAINT fk_item_order FOREIGN KEY (order_id) REFERENCES production_order (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='配合比明细';

-- 罐车与司机
CREATE TABLE truck (
    id           BIGINT       NOT NULL AUTO_INCREMENT,
    plate_no     VARCHAR(32)  NOT NULL COMMENT '车牌号',
    capacity     DECIMAL(6,2) NULL COMMENT '罐体容积 m³',
    driver_name  VARCHAR(32)  NULL COMMENT '司机',
    driver_phone VARCHAR(32)  NULL COMMENT '司机电话',
    status       VARCHAR(16)  NOT NULL COMMENT 'STANDBY/LOADING/ON_ROAD/UNLOADING/WASHING',
    queue_seq    INT          NULL COMMENT '发车排队序号',
    PRIMARY KEY (id),
    UNIQUE KEY uk_truck_plate (plate_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='罐车';

-- 发车单
CREATE TABLE dispatch_ticket (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    ticket_no   VARCHAR(32)  NOT NULL COMMENT '发车单号',
    order_id    BIGINT       NOT NULL COMMENT '任务单',
    truck_id    BIGINT       NOT NULL COMMENT '罐车',
    load_volume DECIMAL(8,2) NULL COMMENT '装车方量 m³',
    load_time   DATETIME     NULL COMMENT '装车时间',
    depart_time DATETIME     NULL COMMENT '出厂时间',
    arrive_time DATETIME     NULL COMMENT '到工地时间',
    sign_volume DECIMAL(8,2) NULL COMMENT '签收方量 m³',
    status      VARCHAR(16)  NOT NULL COMMENT 'LOADED/DEPARTED/ARRIVED/SIGNED',
    remark      VARCHAR(255) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_ticket_no (ticket_no),
    KEY idx_ticket_order (order_id),
    KEY idx_ticket_truck (truck_id),
    CONSTRAINT fk_ticket_order FOREIGN KEY (order_id) REFERENCES production_order (id),
    CONSTRAINT fk_ticket_truck FOREIGN KEY (truck_id) REFERENCES truck (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='发车单';

-- 原材料筒仓
CREATE TABLE silo (
    id               BIGINT        NOT NULL AUTO_INCREMENT,
    silo_code        VARCHAR(32)   NOT NULL COMMENT '仓号',
    name             VARCHAR(64)   NOT NULL COMMENT '仓名称',
    material_code    VARCHAR(16)   NOT NULL COMMENT 'CEMENT/FLYASH/SLAG/SAND/STONE',
    capacity_ton     DECIMAL(10,2) NULL COMMENT '仓容 吨',
    stock_ton        DECIMAL(10,2) NULL COMMENT '当前库存 吨',
    safety_stock_ton DECIMAL(10,2) NULL COMMENT '安全库存 吨',
    PRIMARY KEY (id),
    UNIQUE KEY uk_silo_code (silo_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='原材料筒仓';

-- 补料申请
CREATE TABLE replenish_request (
    id           BIGINT        NOT NULL AUTO_INCREMENT,
    request_no   VARCHAR(32)   NOT NULL COMMENT '申请单号',
    silo_id      BIGINT        NOT NULL COMMENT '筒仓',
    quantity_ton DECIMAL(10,2) NULL COMMENT '补料量 吨',
    applicant    VARCHAR(32)   NULL COMMENT '申请人',
    status       VARCHAR(16)   NOT NULL COMMENT 'PENDING/APPROVED/REJECTED',
    created_at   DATETIME      NULL COMMENT '申请时间',
    decided_by   VARCHAR(32)   NULL COMMENT '审批人',
    decided_at   DATETIME      NULL COMMENT '审批时间',
    remark       VARCHAR(255)  NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_request_no (request_no),
    KEY idx_request_silo (silo_id),
    CONSTRAINT fk_request_silo FOREIGN KEY (silo_id) REFERENCES silo (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='补料申请';

-- 主机临时故障停机处置记录
CREATE TABLE fault_shutdown_record (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    record_no     VARCHAR(32)  NOT NULL COMMENT '处置单号',
    mixer_id      BIGINT       NOT NULL COMMENT '故障主机',
    reason        VARCHAR(255) NOT NULL COMMENT '故障原因',
    occurred_at   DATETIME     NOT NULL COMMENT '故障发生时间',
    confirmed_at  DATETIME     NOT NULL COMMENT '确认处置时间',
    operator_name VARCHAR(32)  NULL COMMENT '调度员',
    status        VARCHAR(16)  NOT NULL COMMENT 'CONFIRMED',
    PRIMARY KEY (id),
    UNIQUE KEY uk_fault_record_no (record_no),
    KEY idx_fault_mixer (mixer_id),
    CONSTRAINT fk_fault_mixer FOREIGN KEY (mixer_id) REFERENCES mixer (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='主机临时故障停机处置记录';

-- 故障任务改派明细
CREATE TABLE fault_reassignment (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    record_id       BIGINT       NOT NULL COMMENT '故障处置单',
    order_id        BIGINT       NOT NULL COMMENT '改派任务单',
    source_mixer_id BIGINT       NOT NULL COMMENT '原主机',
    target_mixer_id BIGINT       NOT NULL COMMENT '接替主机',
    planned_start   DATETIME     NOT NULL COMMENT '原计划开始',
    planned_end     DATETIME     NOT NULL COMMENT '原计划结束',
    PRIMARY KEY (id),
    KEY idx_fault_reassign_order (order_id),
    KEY idx_fault_reassign_record (record_id),
    KEY idx_fault_reassign_target (target_mixer_id),
    CONSTRAINT fk_fault_reassign_record FOREIGN KEY (record_id) REFERENCES fault_shutdown_record (id),
    CONSTRAINT fk_fault_reassign_order FOREIGN KEY (order_id) REFERENCES production_order (id),
    CONSTRAINT fk_fault_reassign_source FOREIGN KEY (source_mixer_id) REFERENCES mixer (id),
    CONSTRAINT fk_fault_reassign_target FOREIGN KEY (target_mixer_id) REFERENCES mixer (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='故障任务改派明细';

-- 试块组（留样登记：关联同一任务下已装车的发车单，快照工程/强度等级/配合比）
CREATE TABLE sample_group (
    id             BIGINT        NOT NULL AUTO_INCREMENT,
    group_no       VARCHAR(40)   NOT NULL COMMENT '试块组编号（服务端生成 SG-试块编号）',
    sample_no      VARCHAR(32)   NOT NULL COMMENT '试块编号（业务唯一，并发登记只成功一次）',
    order_id       BIGINT        NOT NULL COMMENT '生产任务单',
    ticket_id      BIGINT        NOT NULL COMMENT '关联发车单（必须已装车）',
    sample_time    DATETIME      NOT NULL COMMENT '取样时间',
    curing_method  VARCHAR(16)   NOT NULL COMMENT '养护方式 STANDARD/SAME_CONDITION',
    inspector      VARCHAR(32)   NOT NULL COMMENT '登记质检员',
    project_name   VARCHAR(128)  NOT NULL COMMENT '工程名称快照',
    strength_grade VARCHAR(8)    NOT NULL COMMENT '强度等级快照',
    mix_snapshot   VARCHAR(1024) NOT NULL COMMENT '配合比快照 JSON',
    status         VARCHAR(16)   NOT NULL COMMENT 'TESTING/QUALIFIED/RECHECKING/UNQUALIFIED',
    created_at     DATETIME      NOT NULL COMMENT '登记时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_sample_group_no (group_no),
    UNIQUE KEY uk_sample_no (sample_no),
    KEY idx_sample_order (order_id),
    KEY idx_sample_ticket (ticket_id),
    KEY idx_sample_status (status),
    CONSTRAINT fk_sample_order FOREIGN KEY (order_id) REFERENCES production_order (id),
    CONSTRAINT fk_sample_ticket FOREIGN KEY (ticket_id) REFERENCES dispatch_ticket (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='混凝土试块组';

-- 龄期检测项（每组按取样时间生成 7 天 / 28 天各一条，三块强度录入后服务端统一判定）
CREATE TABLE test_item (
    id           BIGINT       NOT NULL AUTO_INCREMENT,
    sample_id    BIGINT       NOT NULL COMMENT '试块组',
    age_days     INT          NOT NULL COMMENT '龄期 7/28',
    due_date     DATE         NOT NULL COMMENT '应检日期（取样日 + 龄期）',
    status       VARCHAR(16)  NOT NULL COMMENT 'PENDING/DONE',
    strength1    DECIMAL(6,2) NULL COMMENT '第 1 块抗压强度 MPa',
    strength2    DECIMAL(6,2) NULL COMMENT '第 2 块抗压强度 MPa',
    strength3    DECIMAL(6,2) NULL COMMENT '第 3 块抗压强度 MPa',
    avg_strength DECIMAL(6,2) NULL COMMENT '平均值（服务端计算）',
    min_strength DECIMAL(6,2) NULL COMMENT '最小值（服务端计算）',
    verdict      VARCHAR(8)   NULL COMMENT '判定 PASS/FAIL（7 天为趋势判定）',
    tested_by    VARCHAR(32)  NULL COMMENT '检测人',
    tested_at    DATETIME     NULL COMMENT '检测时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_item_sample_age (sample_id, age_days),
    KEY idx_item_due (status, due_date),
    CONSTRAINT fk_item_sample FOREIGN KEY (sample_id) REFERENCES sample_group (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='试块龄期检测项';

-- 复检任务（28 天未达门槛时生成，每个原检测项最多一条；原始读数在 test_item 上不可覆盖）
CREATE TABLE recheck_task (
    id             BIGINT       NOT NULL AUTO_INCREMENT,
    recheck_no     VARCHAR(40)  NOT NULL COMMENT '复检单号（RH-试块编号）',
    sample_id      BIGINT       NOT NULL COMMENT '试块组',
    origin_item_id BIGINT       NOT NULL COMMENT '原 28 天检测项（唯一，防重复复检）',
    status         VARCHAR(16)  NOT NULL COMMENT 'PENDING/DONE',
    strength1      DECIMAL(6,2) NULL COMMENT '复检第 1 块抗压强度 MPa',
    strength2      DECIMAL(6,2) NULL COMMENT '复检第 2 块抗压强度 MPa',
    strength3      DECIMAL(6,2) NULL COMMENT '复检第 3 块抗压强度 MPa',
    avg_strength   DECIMAL(6,2) NULL COMMENT '复检平均值（服务端计算）',
    min_strength   DECIMAL(6,2) NULL COMMENT '复检最小值（服务端计算）',
    verdict        VARCHAR(8)   NULL COMMENT '复检判定 PASS/FAIL',
    tested_by      VARCHAR(32)  NULL COMMENT '复检人',
    tested_at      DATETIME     NULL COMMENT '复检时间',
    created_at     DATETIME     NOT NULL COMMENT '复检任务生成时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_recheck_no (recheck_no),
    UNIQUE KEY uk_recheck_origin (origin_item_id),
    KEY idx_recheck_sample (sample_id),
    CONSTRAINT fk_recheck_sample FOREIGN KEY (sample_id) REFERENCES sample_group (id),
    CONSTRAINT fk_recheck_origin FOREIGN KEY (origin_item_id) REFERENCES test_item (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='试块复检任务';

-- ========================= 种子数据 =========================

INSERT INTO mixing_plant (plant_code, name, line_count, location) VALUES
('JL-01', '1 号搅拌楼', 2, '厂区东侧 A 区'),
('JL-02', '2 号搅拌楼', 2, '厂区东侧 B 区'),
('JL-03', '3 号搅拌楼', 1, '厂区西侧 C 区');

INSERT INTO mixer (mixer_code, name, model, theoretical_capacity, daily_plan_volume, status, plant_id) VALUES
('HZS120-1', '1# 主机', 'HZS120', 120.00,  72.00, 'RUNNING',     1),
('HZS120-2', '2# 主机', 'HZS120', 120.00,  96.00, 'RUNNING',     1),
('HZS180-3', '3# 主机', 'HZS180', 180.00,  90.00, 'RUNNING',     2),
('HZS180-4', '4# 主机', 'HZS180', 180.00, 130.00, 'RUNNING',     2),
('HZS120-5', '5# 主机', 'HZS120', 120.00,  58.00, 'RUNNING',     3),
('HZS090-6', '6# 主机', 'HZS90',   90.00,  55.00, 'MAINTENANCE', 3),
('HZS180-7', '7# 主机', 'HZS180', 180.00,  88.00, 'FAULT',       1),
('HZS180-8', '8# 主机', 'HZS180', 180.00,  74.00, 'IDLE',        2);

INSERT INTO production_order (order_no, project_name, contractor, pour_part, strength_grade, planned_volume,
                              slump, status, planned_start, planned_end, water_binder_ratio, remark, mixer_id) VALUES
('SC-2601', '滨海国际中心 A 座', '中建三局集团有限公司', '地下室底板 C 区', 'C35', 860.00, '180±30mm', 'DONE',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '08:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '16:00:00'),
   0.375, '夜间连续浇筑，需 3 台泵车配合', 3),
('SC-2602', '云顶天境 3 号楼', '中天建设集团有限公司', '三层剪力墙', 'C30', 620.00, '160±30mm', 'DONE',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '15:00:00'),
   0.430, '墙体现浇，坍落度严格控制', 1),
('SC-2603', '高新产业园标准厂房', '中铁十四局集团有限公司', '一层柱梁板', 'C30', 740.00, '180±30mm', 'DONE',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '08:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '17:00:00'),
   0.430, '泵送施工，罐车到场间隔不超过 25 分钟', 5),
('SC-2604', '江滨路综合管廊', '上海隧道工程有限公司', '管廊底板 K2+300', 'C40', 480.00, '160±30mm', 'PRODUCING',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '13:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '21:00:00'),
   0.336, '抗渗 P8，掺膨胀剂，同条件试块 3 组', 3),
('SC-2605', '星海城 7 号楼', '中建八局集团有限公司', '二层顶板', 'C25', 560.00, '180±30mm', 'DONE',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '16:00:00'),
   0.514, '板面收面要求高，控制初凝时间', 2),
('SC-2606', '城东污水处理厂二期', '北京城建集团有限责任公司', '沉淀池壁板', 'C35', 690.00, '140±30mm', 'PRODUCING',
   TIMESTAMP(CURDATE(), '07:00:00'), TIMESTAMP(CURDATE(), '15:00:00'),
   0.375, '抗渗混凝土，分层浇筑每层不超过 50cm', 1),
('SC-2607', '云顶天境 5 号楼', '中天建设集团有限公司', '四层梁板', 'C30', 820.00, '180±30mm', 'PRODUCING',
   TIMESTAMP(CURDATE(), '08:00:00'), TIMESTAMP(CURDATE(), '18:00:00'),
   0.430, '大方量连续供应，备用罐车不少于 2 台', 4),
('SC-2608', '滨海国际中心 B 座', '中建三局集团有限公司', '二层柱', 'C40', 540.00, '160±30mm', 'PENDING',
   TIMESTAMP(CURDATE(), '13:00:00'), TIMESTAMP(CURDATE(), '22:00:00'),
   0.336, '高强柱，需延长搅拌时间 30s', 3),
('SC-2609', '高铁站前广场配套', '中铁四局集团有限公司', '站台层铺装', 'C25', 430.00, '120±30mm', 'PENDING',
   TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 1 DAY), '08:00:00'), TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 1 DAY), '14:00:00'),
   0.514, '干硬性混凝土，罐车卸料注意离析', 5),
('SC-2610', '江滨路综合管廊', '上海隧道工程有限公司', '管廊侧墙 K3+100', 'C40', 610.00, '160±30mm', 'PENDING',
   TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 1 DAY), '09:00:00'), TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 1 DAY), '19:00:00'),
   0.336, '侧墙对称浇筑，两侧高差不超过 50cm', 8),
('SC-2611', '星海城地下车库', '中建八局集团有限公司', '车库顶板后浇带', 'C30', 380.00, '180±30mm', 'PENDING',
   TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 2 DAY), '08:00:00'), TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 2 DAY), '12:00:00'),
   0.430, '微膨胀混凝土，待主体沉降稳定后施工', 2),
('SC-2612', '高新产业园配套楼', '中铁十四局集团有限公司', '屋面刚性保护层', 'C25', 260.00, '120±30mm', 'PENDING',
   TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 2 DAY), '13:00:00'), TIMESTAMP(DATE_ADD(CURDATE(), INTERVAL 2 DAY), '17:00:00'),
   0.514, '保护层 40mm，随捣随抹', 5),
-- 历史已完成任务单（试块质检闭环演示：7 天 / 28 天 / 复检各状态）
('SC-2588', '河西政务服务中心', '江苏省建工集团有限公司', '主楼筏板基础', 'C35', 720.00, '180±30mm', 'DONE',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '08:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '18:00:00'),
   0.375, '筏板大体积混凝土，标准养护试块 4 组', 2),
('SC-2589', '滨河路立交桥', '中交第二航务工程局有限公司', '3# 桥墩承台', 'C30', 540.00, '160±30mm', 'DONE',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 12 DAY), '08:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 12 DAY), '17:00:00'),
   0.430, '承台混凝土，试块 7 天强度跟踪', 4),
('SC-2590', '会展中心二期', '上海建工集团股份有限公司', '展厅耐磨地面', 'C40', 460.00, '160±30mm', 'DONE',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '08:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '16:00:00'),
   0.336, '耐磨地面，试块今日到 7 天龄期', 3);

-- 配合比明细：按任务单强度等级套用参考配合比（kg/m³）
INSERT INTO mix_ratio_item (order_id, material_code, material_name, dosage, ratio_percent, seq)
SELECT o.id, d.code, d.name, d.dosage,
       ROUND(d.dosage / d.total * 100, 2), d.seq
FROM production_order o
JOIN (
    SELECT 'C25' AS grade, 'CEMENT'    AS code, '水泥 P·O42.5'    AS name, 230.00 AS dosage, 1 AS seq, 2366.80 AS total UNION ALL
    SELECT 'C25', 'FLYASH',   '粉煤灰 Ⅱ 级',   70.00, 2, 2366.80 UNION ALL
    SELECT 'C25', 'SLAG',     '矿粉 S95',      50.00, 3, 2366.80 UNION ALL
    SELECT 'C25', 'SAND',     '机制砂 中砂',  780.00, 4, 2366.80 UNION ALL
    SELECT 'C25', 'STONE',    '碎石 5-25mm', 1050.00, 5, 2366.80 UNION ALL
    SELECT 'C25', 'WATER',    '拌合用水',      180.00, 6, 2366.80 UNION ALL
    SELECT 'C25', 'ADMIXTURE','聚羧酸外加剂',    6.80, 7, 2366.80 UNION ALL
    SELECT 'C30', 'CEMENT',   '水泥 P·O42.5',  270.00, 1, 2379.80 UNION ALL
    SELECT 'C30', 'FLYASH',   '粉煤灰 Ⅱ 级',   70.00, 2, 2379.80 UNION ALL
    SELECT 'C30', 'SLAG',     '矿粉 S95',      60.00, 3, 2379.80 UNION ALL
    SELECT 'C30', 'SAND',     '机制砂 中砂',  760.00, 4, 2379.80 UNION ALL
    SELECT 'C30', 'STONE',    '碎石 5-25mm', 1040.00, 5, 2379.80 UNION ALL
    SELECT 'C30', 'WATER',    '拌合用水',      172.00, 6, 2379.80 UNION ALL
    SELECT 'C30', 'ADMIXTURE','聚羧酸外加剂',    7.80, 7, 2379.80 UNION ALL
    SELECT 'C35', 'CEMENT',   '水泥 P·O42.5',  310.00, 1, 2374.20 UNION ALL
    SELECT 'C35', 'FLYASH',   '粉煤灰 Ⅱ 级',   60.00, 2, 2374.20 UNION ALL
    SELECT 'C35', 'SLAG',     '矿粉 S95',      70.00, 3, 2374.20 UNION ALL
    SELECT 'C35', 'SAND',     '机制砂 中砂',  730.00, 4, 2374.20 UNION ALL
    SELECT 'C35', 'STONE',    '碎石 5-25mm', 1030.00, 5, 2374.20 UNION ALL
    SELECT 'C35', 'WATER',    '拌合用水',      165.00, 6, 2374.20 UNION ALL
    SELECT 'C35', 'ADMIXTURE','聚羧酸外加剂',    9.20, 7, 2374.20 UNION ALL
    SELECT 'C40', 'CEMENT',   '水泥 P·O42.5',  350.00, 1, 2358.80 UNION ALL
    SELECT 'C40', 'FLYASH',   '粉煤灰 Ⅱ 级',   50.00, 2, 2358.80 UNION ALL
    SELECT 'C40', 'SLAG',     '矿粉 S95',      70.00, 3, 2358.80 UNION ALL
    SELECT 'C40', 'SAND',     '机制砂 中砂',  700.00, 4, 2358.80 UNION ALL
    SELECT 'C40', 'STONE',    '碎石 5-25mm', 1020.00, 5, 2358.80 UNION ALL
    SELECT 'C40', 'WATER',    '拌合用水',      158.00, 6, 2358.80 UNION ALL
    SELECT 'C40', 'ADMIXTURE','聚羧酸外加剂',   10.80, 7, 2358.80
) d ON d.grade = o.strength_grade;

INSERT INTO truck (plate_no, capacity, driver_name, driver_phone, status, queue_seq) VALUES
('鲁A·T1201', 12.00, '王建国', '13805310001', 'STANDBY',   1),
('鲁A·T1202', 12.00, '李海涛', '13805310002', 'STANDBY',   2),
('鲁A·T1203', 10.00, '张 伟',  '13805310003', 'STANDBY',   3),
('鲁A·T1204', 10.00, '刘志强', '13805310004', 'LOADING',   4),
('鲁A·T1205', 15.00, '陈立明', '13805310005', 'WASHING',   5),
('鲁A·T1206', 15.00, '赵永刚', '13805310006', 'ON_ROAD',   6),
('鲁A·T1207', 12.00, '孙 磊',  '13805310007', 'UNLOADING', 7),
('鲁A·T1208', 10.00, '周文斌', '13805310008', 'ON_ROAD',   8),
('鲁A·T1209', 12.00, '吴国庆', '13805310009', 'ON_ROAD',   9),
('鲁A·T1210',  8.00, '郑小川', '13805310010', 'LOADING',  10);

INSERT INTO dispatch_ticket (ticket_no, order_id, truck_id, load_volume, load_time, depart_time, arrive_time,
                             sign_volume, status, remark) VALUES
-- SC-2601（前天）
('FC-0001', 1, 1, 12.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '08:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '08:12:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '08:55:00'), 11.80, 'SIGNED', '首车，工地签收回单齐全'),
('FC-0002', 1, 3, 12.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '08:30:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '08:42:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:25:00'), 11.90, 'SIGNED', NULL),
('FC-0003', 1, 5, 11.50, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:13:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:58:00'), 11.50, 'SIGNED', NULL),
('FC-0004', 1, 7, 11.50, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:30:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:44:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '10:30:00'), 11.30, 'SIGNED', '途中堵车 12 分钟'),
('FC-0005', 1, 8, 11.50, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '10:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '10:15:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '11:02:00'), 11.40, 'SIGNED', NULL),
('FC-0006', 1, 9, 12.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '10:30:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '10:41:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '11:20:00'), 12.00, 'SIGNED', NULL),
-- SC-2602（前天）
('FC-0007', 2, 2, 10.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:10:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:52:00'),  9.80, 'SIGNED', NULL),
('FC-0008', 2, 4, 10.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:40:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '09:51:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '10:35:00'), 10.00, 'SIGNED', NULL),
('FC-0009', 2, 6, 10.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '10:20:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '10:33:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '11:18:00'),  9.90, 'SIGNED', NULL),
('FC-0010', 2, 10, 9.50, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '11:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '11:12:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '11:55:00'),  9.40, 'SIGNED', NULL),
('FC-0011', 2, 1, 9.50, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '11:40:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '11:52:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '12:35:00'),  9.50, 'SIGNED', '午间收车'),
-- SC-2603（昨天）
('FC-0012', 3, 3, 12.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '08:10:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '08:21:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:05:00'), 11.80, 'SIGNED', NULL),
('FC-0013', 3, 5, 12.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '08:50:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:02:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:47:00'), 12.00, 'SIGNED', NULL),
('FC-0014', 3, 7, 12.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:30:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:42:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '10:28:00'), 11.70, 'SIGNED', NULL),
('FC-0015', 3, 8, 12.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '10:10:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '10:23:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '11:08:00'), 11.90, 'SIGNED', NULL),
('FC-0016', 3, 9, 11.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '10:50:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '11:01:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '11:45:00'), 11.00, 'SIGNED', NULL),
-- SC-2604（昨天下午，生产中）
('FC-0017', 4, 1, 11.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '13:20:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '13:31:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '14:16:00'), 10.90, 'SIGNED', NULL),
('FC-0018', 4, 2, 11.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '14:10:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '14:22:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '15:05:00'), 11.00, 'SIGNED', NULL),
('FC-0019', 4, 4, 11.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '15:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '15:11:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '15:58:00'), NULL, 'ARRIVED', '工地泵车排队中'),
('FC-0020', 4, 6, 10.50, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '15:50:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '16:02:00'), NULL, NULL, 'DEPARTED', NULL),
-- SC-2605（昨天）
('FC-0021', 5, 10, 9.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:20:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:31:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '10:15:00'), 8.90, 'SIGNED', NULL),
('FC-0022', 5, 1, 9.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '10:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '10:12:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '10:56:00'), 9.00, 'SIGNED', NULL),
('FC-0023', 5, 2, 9.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '10:40:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '10:52:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '11:36:00'), 8.80, 'SIGNED', NULL),
('FC-0024', 5, 3, 8.50, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '11:20:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '11:33:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '12:18:00'), 8.50, 'SIGNED', NULL),
-- SC-2606（今天，生产中）
('FC-0025', 6, 5, 10.50, TIMESTAMP(CURDATE(), '07:30:00'), TIMESTAMP(CURDATE(), '07:41:00'), TIMESTAMP(CURDATE(), '08:26:00'), 10.40, 'SIGNED', NULL),
('FC-0026', 6, 7, 10.50, TIMESTAMP(CURDATE(), '08:20:00'), TIMESTAMP(CURDATE(), '08:33:00'), TIMESTAMP(CURDATE(), '09:18:00'), NULL, 'ARRIVED', '等待泵送'),
('FC-0027', 6, 8, 10.00, TIMESTAMP(CURDATE(), '09:10:00'), TIMESTAMP(CURDATE(), '09:22:00'), NULL, NULL, 'DEPARTED', NULL),
-- SC-2607（今天，生产中）
('FC-0028', 7, 9, 12.00, TIMESTAMP(CURDATE(), '08:20:00'), TIMESTAMP(CURDATE(), '08:31:00'), NULL, NULL, 'DEPARTED', NULL),
('FC-0029', 7, 10, 12.00, TIMESTAMP(CURDATE(), '09:00:00'), NULL, NULL, NULL, 'LOADED', '等待出厂检验'),
('FC-0030', 7, 4, 12.00, TIMESTAMP(CURDATE(), '09:40:00'), NULL, NULL, NULL, 'LOADED', NULL),
-- SC-2588（35 天前，试块留样来源）
('FC-0031', 13, 1, 12.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '08:20:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '08:33:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '09:15:00'), 12.00, 'SIGNED', NULL),
('FC-0032', 13, 3, 12.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '10:10:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '10:22:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '11:05:00'), 11.90, 'SIGNED', NULL),
('FC-0033', 13, 5, 11.50, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '13:40:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '13:52:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '14:35:00'), 11.50, 'SIGNED', NULL),
-- SC-2589（12 天前）
('FC-0034', 14, 2, 12.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 12 DAY), '08:40:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 12 DAY), '08:51:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 12 DAY), '09:30:00'), 11.80, 'SIGNED', NULL),
-- SC-2590（7 天前）
('FC-0035', 15, 4, 11.00, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '08:30:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '08:42:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '09:20:00'), 11.00, 'SIGNED', NULL);

INSERT INTO silo (silo_code, name, material_code, capacity_ton, stock_ton, safety_stock_ton) VALUES
('SIL-C01', '1# 水泥仓',  'CEMENT', 200.00, 132.50, 40.00),
('SIL-C02', '2# 水泥仓',  'CEMENT', 200.00,  88.00, 40.00),
('SIL-F01', '1# 粉煤灰仓', 'FLYASH', 120.00,  26.40, 30.00),
('SIL-F02', '2# 粉煤灰仓', 'FLYASH', 120.00,  74.60, 30.00),
('SIL-K01', '1# 矿粉仓',  'SLAG',   120.00,  52.30, 25.00),
('SIL-K02', '2# 矿粉仓',  'SLAG',   120.00,  18.90, 25.00),
('SIL-S01', '1# 砂仓',    'SAND',   600.00, 412.00, 120.00),
('SIL-G01', '1# 碎石仓',  'STONE',  800.00, 505.00, 150.00);

INSERT INTO replenish_request (request_no, silo_id, quantity_ton, applicant, status, created_at, decided_by,
                               decided_at, remark) VALUES
('BL-2601', 3,  60.00, '王建国', 'PENDING',  TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:20:00'), NULL, NULL,
   '粉煤灰库存逼近安全线，明日 C30 大方量需备料'),
('BL-2602', 6,  45.00, '李海涛', 'PENDING',  TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '14:05:00'), NULL, NULL,
   '矿粉仓低于安全库存，影响 C35/C40 配比'),
('BL-2603', 8, 120.00, '张 伟',  'PENDING',  TIMESTAMP(CURDATE(), '07:40:00'), NULL, NULL,
   '碎石储备不足，江滨路管廊连续浇筑需提前备料'),
('BL-2604', 1,  80.00, '王建国', 'APPROVED', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '10:15:00'), '调度主管 周炯',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '10:40:00'), '供应商晨间已送达'),
('BL-2605', 2,  60.00, '刘志强', 'APPROVED', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '16:20:00'), '调度主管 周炯',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '16:50:00'), NULL),
('BL-2606', 7,  90.00, '陈立明', 'APPROVED', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '08:30:00'), '生产经理 何斌',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '09:00:00'), '机制砂含水率偏高，已复检'),
('BL-2607', 4,  30.00, '赵永刚', 'REJECTED', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '11:00:00'), '调度主管 周炯',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '11:30:00'), '供应商批次未定，暂缓采购'),
('BL-2608', 5,  25.00, '孙 磊',  'REJECTED', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '15:40:00'), '生产经理 何斌',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 1 DAY), '16:10:00'), '仓位尚可，先消化现有库存');

-- 试块组留样（快照与对应任务单一致；C35 阈值：均值≥40.25 且最小值≥33.25，7 天趋势参考≥26.25）
INSERT INTO sample_group (group_no, sample_no, order_id, ticket_id, sample_time, curing_method, inspector,
                          project_name, strength_grade, mix_snapshot, status, created_at) VALUES
('SG-SK-0001', 'SK-0001', 13, 31, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '08:30:00'), 'STANDARD', '王雪梅',
   '河西政务服务中心', 'C35',
   '[{"material":"水泥 P·O42.5","dosage":310},{"material":"粉煤灰 Ⅱ 级","dosage":60},{"material":"矿粉 S95","dosage":70},{"material":"机制砂 中砂","dosage":730},{"material":"碎石 5-25mm","dosage":1030},{"material":"拌合用水","dosage":165},{"material":"聚羧酸外加剂","dosage":9.2}]',
   'QUALIFIED', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '08:32:00')),
('SG-SK-0002', 'SK-0002', 13, 32, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '10:30:00'), 'STANDARD', '王雪梅',
   '河西政务服务中心', 'C35',
   '[{"material":"水泥 P·O42.5","dosage":310},{"material":"粉煤灰 Ⅱ 级","dosage":60},{"material":"矿粉 S95","dosage":70},{"material":"机制砂 中砂","dosage":730},{"material":"碎石 5-25mm","dosage":1030},{"material":"拌合用水","dosage":165},{"material":"聚羧酸外加剂","dosage":9.2}]',
   'RECHECKING', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '10:33:00')),
('SG-SK-0003', 'SK-0003', 13, 33, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '14:00:00'), 'SAME_CONDITION', '李 谨',
   '河西政务服务中心', 'C35',
   '[{"material":"水泥 P·O42.5","dosage":310},{"material":"粉煤灰 Ⅱ 级","dosage":60},{"material":"矿粉 S95","dosage":70},{"material":"机制砂 中砂","dosage":730},{"material":"碎石 5-25mm","dosage":1030},{"material":"拌合用水","dosage":165},{"material":"聚羧酸外加剂","dosage":9.2}]',
   'QUALIFIED', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '14:02:00')),
('SG-SK-0004', 'SK-0004', 13, 31, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '15:30:00'), 'STANDARD', '李 谨',
   '河西政务服务中心', 'C35',
   '[{"material":"水泥 P·O42.5","dosage":310},{"material":"粉煤灰 Ⅱ 级","dosage":60},{"material":"矿粉 S95","dosage":70},{"material":"机制砂 中砂","dosage":730},{"material":"碎石 5-25mm","dosage":1030},{"material":"拌合用水","dosage":165},{"material":"聚羧酸外加剂","dosage":9.2}]',
   'UNQUALIFIED', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 35 DAY), '15:33:00')),
('SG-SK-0005', 'SK-0005', 14, 34, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 12 DAY), '09:00:00'), 'STANDARD', '王雪梅',
   '滨河路立交桥', 'C30',
   '[{"material":"水泥 P·O42.5","dosage":270},{"material":"粉煤灰 Ⅱ 级","dosage":70},{"material":"矿粉 S95","dosage":60},{"material":"机制砂 中砂","dosage":760},{"material":"碎石 5-25mm","dosage":1040},{"material":"拌合用水","dosage":172},{"material":"聚羧酸外加剂","dosage":7.8}]',
   'TESTING', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 12 DAY), '09:03:00')),
('SG-SK-0006', 'SK-0006', 15, 35, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '08:40:00'), 'STANDARD', '李 谨',
   '会展中心二期', 'C40',
   '[{"material":"水泥 P·O42.5","dosage":350},{"material":"粉煤灰 Ⅱ 级","dosage":50},{"material":"矿粉 S95","dosage":70},{"material":"机制砂 中砂","dosage":700},{"material":"碎石 5-25mm","dosage":1020},{"material":"拌合用水","dosage":158},{"material":"聚羧酸外加剂","dosage":10.8}]',
   'TESTING', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '08:43:00')),
('SG-SK-0007', 'SK-0007', 1, 1, TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '08:20:00'), 'SAME_CONDITION', '王雪梅',
   '滨海国际中心 A 座', 'C35',
   '[{"material":"水泥 P·O42.5","dosage":310},{"material":"粉煤灰 Ⅱ 级","dosage":60},{"material":"矿粉 S95","dosage":70},{"material":"机制砂 中砂","dosage":730},{"material":"碎石 5-25mm","dosage":1030},{"material":"拌合用水","dosage":165},{"material":"聚羧酸外加剂","dosage":9.2}]',
   'TESTING', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 2 DAY), '08:24:00')),
('SG-SK-0008', 'SK-0008', 6, 25, TIMESTAMP(CURDATE(), '07:50:00'), 'STANDARD', '李 谨',
   '城东污水处理厂二期', 'C35',
   '[{"material":"水泥 P·O42.5","dosage":310},{"material":"粉煤灰 Ⅱ 级","dosage":60},{"material":"矿粉 S95","dosage":70},{"material":"机制砂 中砂","dosage":730},{"material":"碎石 5-25mm","dosage":1030},{"material":"拌合用水","dosage":165},{"material":"聚羧酸外加剂","dosage":9.2}]',
   'TESTING', TIMESTAMP(CURDATE(), '07:55:00'));

-- 龄期检测项（已录入的读数与判定均由服务端同一套规则算出，此处种子与规则保持一致）
INSERT INTO test_item (sample_id, age_days, due_date, status, strength1, strength2, strength3,
                       avg_strength, min_strength, verdict, tested_by, tested_at) VALUES
(1,  7, DATE_SUB(CURDATE(), INTERVAL 28 DAY), 'DONE', 28.50, 29.00, 27.80, 28.43, 27.80, 'PASS', '王雪梅', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 28 DAY), '10:00:00')),
(1, 28, DATE_SUB(CURDATE(), INTERVAL 7 DAY),  'DONE', 41.20, 40.50, 39.80, 40.50, 39.80, 'PASS', '王雪梅', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '09:30:00')),
(2,  7, DATE_SUB(CURDATE(), INTERVAL 28 DAY), 'DONE', 26.10, 25.80, 26.90, 26.27, 25.80, 'PASS', '王雪梅', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 28 DAY), '10:05:00')),
(2, 28, DATE_SUB(CURDATE(), INTERVAL 7 DAY),  'DONE', 38.20, 36.50, 33.10, 35.93, 33.10, 'FAIL', '王雪梅', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '09:40:00')),
(3,  7, DATE_SUB(CURDATE(), INTERVAL 28 DAY), 'DONE', 27.00, 26.50, 27.20, 26.90, 26.50, 'PASS', '李 谨', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 28 DAY), '11:00:00')),
(3, 28, DATE_SUB(CURDATE(), INTERVAL 7 DAY),  'DONE', 39.00, 38.20, 34.00, 37.07, 34.00, 'FAIL', '李 谨', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '10:00:00')),
(4,  7, DATE_SUB(CURDATE(), INTERVAL 28 DAY), 'DONE', 25.50, 26.00, 25.20, 25.57, 25.20, 'FAIL', '李 谨', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 28 DAY), '11:20:00')),
(4, 28, DATE_SUB(CURDATE(), INTERVAL 7 DAY),  'DONE', 36.00, 35.20, 33.00, 34.73, 33.00, 'FAIL', '李 谨', TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '10:20:00')),
(5,  7, DATE_SUB(CURDATE(), INTERVAL 5 DAY),  'PENDING', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(5, 28, DATE_ADD(CURDATE(), INTERVAL 16 DAY), 'PENDING', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(6,  7, CURDATE(),                            'PENDING', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(6, 28, DATE_ADD(CURDATE(), INTERVAL 21 DAY), 'PENDING', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(7,  7, DATE_ADD(CURDATE(), INTERVAL 5 DAY),  'PENDING', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(7, 28, DATE_ADD(CURDATE(), INTERVAL 26 DAY), 'PENDING', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(8,  7, DATE_ADD(CURDATE(), INTERVAL 7 DAY),  'PENDING', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(8, 28, DATE_ADD(CURDATE(), INTERVAL 28 DAY), 'PENDING', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- 复检任务（SK-0002 待复检；SK-0003 复检合格转合格；SK-0004 复检仍失败锁定不合格）
INSERT INTO recheck_task (recheck_no, sample_id, origin_item_id, status, strength1, strength2, strength3,
                          avg_strength, min_strength, verdict, tested_by, tested_at, created_at) VALUES
('RH-SK-0002', 2, 4, 'PENDING', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '10:00:00')),
('RH-SK-0003', 3, 6, 'DONE', 41.00, 40.80, 39.50, 40.43, 39.50, 'PASS', '李 谨',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 5 DAY), '09:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '10:30:00')),
('RH-SK-0004', 4, 8, 'DONE', 38.50, 37.00, 33.80, 36.43, 33.80, 'FAIL', '王雪梅',
   TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 4 DAY), '14:00:00'), TIMESTAMP(DATE_SUB(CURDATE(), INTERVAL 7 DAY), '11:00:00'));
