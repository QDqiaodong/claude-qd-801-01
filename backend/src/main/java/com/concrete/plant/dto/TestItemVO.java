package com.concrete.plant.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

/**
 * 龄期检测项视图：页面展示状态（未到期/待检/逾期/已检）与验收门槛都由服务端推导下发，
 * 前端不做任何阈值计算，避免刷新后判定漂移。
 */
@Getter
@Setter
public class TestItemVO {

    private Long id;
    private Integer ageDays;
    private LocalDate dueDate;
    private String status;
    /** NOT_DUE / DUE / OVERDUE / DONE */
    private String displayStatus;
    private String displayStatusName;
    private BigDecimal strength1;
    private BigDecimal strength2;
    private BigDecimal strength3;
    private BigDecimal avgStrength;
    private BigDecimal minStrength;
    private String verdict;
    /** 7 天：趋势正常/趋势偏低；28 天：合格/不合格 */
    private String verdictName;
    private String testedBy;
    private LocalDateTime testedAt;
    /** 服务端判定依据（展示用）：设计值、28 天均值/最小值门槛、7 天趋势参考 */
    private BigDecimal designStrength;
    private BigDecimal avgThreshold;
    private BigDecimal minThreshold;
    private BigDecimal trendReference;
}
