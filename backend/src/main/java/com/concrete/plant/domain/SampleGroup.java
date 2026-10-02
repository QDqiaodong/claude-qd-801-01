package com.concrete.plant.domain;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import org.hibernate.annotations.BatchSize;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * 混凝土试块组：质检员留样登记时快照工程、强度等级与配合比，
 * 必须关联同一任务单下一张已装车的发车单；试块编号业务唯一。
 * 质量状态机：TESTING → QUALIFIED / RECHECKING → QUALIFIED / UNQUALIFIED（锁定）。
 */
@Entity
@Table(name = "sample_group")
@BatchSize(size = 50)
@Getter
@Setter
public class SampleGroup {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 试块组编号（服务端生成：SG-试块编号） */
    @Column(name = "group_no", nullable = false, unique = true, length = 40)
    private String groupNo;

    /** 试块编号（业务唯一键，并发登记只成功一次） */
    @Column(name = "sample_no", nullable = false, unique = true, length = 32)
    private String sampleNo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false)
    private ProductionOrder order;

    /** 关联发车单（登记时必须已装车） */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "ticket_id", nullable = false)
    private DispatchTicket ticket;

    /** 取样时间（7 天 / 28 天应检日期由它推导） */
    @Column(name = "sample_time", nullable = false)
    private LocalDateTime sampleTime;

    /** 养护方式 STANDARD / SAME_CONDITION */
    @Column(name = "curing_method", nullable = false, length = 16)
    private String curingMethod;

    /** 登记质检员 */
    @Column(name = "inspector", nullable = false, length = 32)
    private String inspector;

    /** 工程名称快照 */
    @Column(name = "project_name", nullable = false, length = 128)
    private String projectName;

    /** 强度等级快照 */
    @Column(name = "strength_grade", nullable = false, length = 8)
    private String strengthGrade;

    /** 配合比快照（JSON，登记后任务单配合比再调整也不影响这里） */
    @Column(name = "mix_snapshot", nullable = false, length = 1024)
    private String mixSnapshot;

    /** 状态 TESTING / QUALIFIED / RECHECKING / UNQUALIFIED */
    @Column(name = "status", nullable = false, length = 16)
    private String status;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @OneToMany(mappedBy = "sampleGroup", cascade = CascadeType.ALL, orphanRemoval = true)
    @BatchSize(size = 50)
    @OrderBy("ageDays asc")
    private List<TestItem> items = new ArrayList<>();

    public void addItem(TestItem item) {
        if (item == null) {
            return;
        }
        item.setSampleGroup(this);
        this.items.add(item);
    }
}
