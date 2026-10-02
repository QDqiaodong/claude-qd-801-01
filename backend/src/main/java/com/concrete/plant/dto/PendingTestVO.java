package com.concrete.plant.dto;

import java.time.LocalDate;

import lombok.Getter;
import lombok.Setter;

/**
 * 待检清单行：龄期检测项（待检/逾期）与待复检任务统一排队。
 */
@Getter
@Setter
public class PendingTestVO {

    /** ITEM = 龄期检测项，RECHECK = 复检任务 */
    private String kind;
    private String kindName;
    /** 检测项 id 或复检任务 id（提交结果时用） */
    private Long refId;
    private Long sampleId;
    private String sampleNo;
    private String projectName;
    private String strengthGrade;
    private Integer ageDays;
    private LocalDate dueDate;
    private String displayStatus;
    private String displayStatusName;
}
