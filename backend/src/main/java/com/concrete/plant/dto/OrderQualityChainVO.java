package com.concrete.plant.dto;

import java.util.ArrayList;
import java.util.List;

import lombok.Getter;
import lombok.Setter;

/**
 * 任务单视角的完整检测链：任务单摘要 + 名下全部试块组（含检测项与复检）。
 */
@Getter
@Setter
public class OrderQualityChainVO {

    private Long orderId;
    private String orderNo;
    private String projectName;
    private String strengthGrade;
    private String orderStatus;
    private String orderStatusName;
    private List<SampleGroupVO> samples = new ArrayList<>();
}
