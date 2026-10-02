package com.concrete.plant.dto;

import java.math.BigDecimal;

import lombok.Getter;
import lombok.Setter;

/**
 * 检测项 / 复检结果录入请求体：三块抗压强度 + 操作者。
 * 平均值、最小值与判定一律由服务端按强度等级设计值计算，前端传的任何阈值都不被采信。
 */
@Getter
@Setter
public class TestResultRequest {

    private BigDecimal strength1;
    private BigDecimal strength2;
    private BigDecimal strength3;
    private String testedBy;
}
