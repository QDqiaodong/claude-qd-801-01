package com.concrete.plant.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

/**
 * 复检任务视图（引用原检测项，保留操作者与时间）。
 */
@Getter
@Setter
public class RecheckTaskVO {

    private Long id;
    private String recheckNo;
    private Long originItemId;
    private String status;
    private String statusName;
    private BigDecimal strength1;
    private BigDecimal strength2;
    private BigDecimal strength3;
    private BigDecimal avgStrength;
    private BigDecimal minStrength;
    private String verdict;
    private String verdictName;
    private String testedBy;
    private LocalDateTime testedAt;
    private LocalDateTime createdAt;
    /** 与原 28 天检测项同一套验收门槛 */
    private BigDecimal avgThreshold;
    private BigDecimal minThreshold;
}
