package com.concrete.plant.dto;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import lombok.Getter;
import lombok.Setter;

/**
 * 试块组视图：留样快照 + 龄期检测项 + 复检任务，完整检测链。
 */
@Getter
@Setter
public class SampleGroupVO {

    private Long id;
    private String groupNo;
    private String sampleNo;
    private LocalDateTime sampleTime;
    private String curingMethod;
    private String curingMethodName;
    private String inspector;
    private Long orderId;
    private String orderNo;
    private Long ticketId;
    private String ticketNo;
    /** 快照：工程名称 / 强度等级 / 配合比（登记时冻结） */
    private String projectName;
    private String strengthGrade;
    private String mixSnapshot;
    private String status;
    private String statusName;
    private LocalDateTime createdAt;
    private List<TestItemVO> items = new ArrayList<>();
    /** 28 天不合格时生成的复检任务（最多一条，无则为 null） */
    private RecheckTaskVO recheck;
}
