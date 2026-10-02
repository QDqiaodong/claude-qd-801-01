package com.concrete.plant.domain;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import org.hibernate.annotations.BatchSize;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * 龄期检测项：登记试块组时按取样时间生成 7 天 / 28 天各一条。
 * 三块抗压强度一经录入不可覆盖（复检走 recheck_task，不回写本表）。
 */
@Entity
@Table(name = "test_item")
@BatchSize(size = 50)
@Getter
@Setter
public class TestItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sample_id", nullable = false)
    private SampleGroup sampleGroup;

    /** 龄期 7 / 28 天 */
    @Column(name = "age_days", nullable = false)
    private Integer ageDays;

    /** 应检日期 = 取样日 + 龄期 */
    @Column(name = "due_date", nullable = false)
    private LocalDate dueDate;

    /** 状态 PENDING / DONE */
    @Column(name = "status", nullable = false, length = 16)
    private String status;

    @Column(name = "strength1", precision = 6, scale = 2)
    private BigDecimal strength1;

    @Column(name = "strength2", precision = 6, scale = 2)
    private BigDecimal strength2;

    @Column(name = "strength3", precision = 6, scale = 2)
    private BigDecimal strength3;

    /** 平均值（服务端按强度等级统一计算） */
    @Column(name = "avg_strength", precision = 6, scale = 2)
    private BigDecimal avgStrength;

    /** 最小值 */
    @Column(name = "min_strength", precision = 6, scale = 2)
    private BigDecimal minStrength;

    /** 判定 PASS / FAIL（7 天为趋势判定，28 天为验收判定） */
    @Column(name = "verdict", length = 8)
    private String verdict;

    @Column(name = "tested_by", length = 32)
    private String testedBy;

    @Column(name = "tested_at")
    private LocalDateTime testedAt;
}
