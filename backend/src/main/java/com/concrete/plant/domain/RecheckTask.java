package com.concrete.plant.domain;

import java.math.BigDecimal;
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
 * 复检任务：28 天检测未达门槛时生成，origin_item_id 唯一约束保证
 * 同一原检测项只会有一条复检任务；复检必须引用原检测并保留操作者与时间。
 */
@Entity
@Table(name = "recheck_task")
@BatchSize(size = 50)
@Getter
@Setter
public class RecheckTask {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 复检单号（RH-试块编号） */
    @Column(name = "recheck_no", nullable = false, unique = true, length = 40)
    private String recheckNo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sample_id", nullable = false)
    private SampleGroup sampleGroup;

    /** 原 28 天检测项（唯一，防重复复检） */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "origin_item_id", nullable = false, unique = true)
    private TestItem originItem;

    /** 状态 PENDING / DONE */
    @Column(name = "status", nullable = false, length = 16)
    private String status;

    @Column(name = "strength1", precision = 6, scale = 2)
    private BigDecimal strength1;

    @Column(name = "strength2", precision = 6, scale = 2)
    private BigDecimal strength2;

    @Column(name = "strength3", precision = 6, scale = 2)
    private BigDecimal strength3;

    @Column(name = "avg_strength", precision = 6, scale = 2)
    private BigDecimal avgStrength;

    @Column(name = "min_strength", precision = 6, scale = 2)
    private BigDecimal minStrength;

    /** 复检判定 PASS / FAIL */
    @Column(name = "verdict", length = 8)
    private String verdict;

    @Column(name = "tested_by", length = 32)
    private String testedBy;

    @Column(name = "tested_at")
    private LocalDateTime testedAt;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;
}
