package com.concrete.plant.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.concrete.plant.common.BizException;
import com.concrete.plant.common.Dict;
import com.concrete.plant.domain.DispatchTicket;
import com.concrete.plant.domain.MixRatioItem;
import com.concrete.plant.domain.ProductionOrder;
import com.concrete.plant.domain.RecheckTask;
import com.concrete.plant.domain.SampleGroup;
import com.concrete.plant.domain.TestItem;
import com.concrete.plant.dto.OrderQualityChainVO;
import com.concrete.plant.dto.PendingTestVO;
import com.concrete.plant.dto.RecheckTaskVO;
import com.concrete.plant.dto.SampleGroupRequest;
import com.concrete.plant.dto.SampleGroupVO;
import com.concrete.plant.dto.TestItemVO;
import com.concrete.plant.dto.TestResultRequest;
import com.concrete.plant.repository.DispatchTicketRepository;
import com.concrete.plant.repository.ProductionOrderRepository;
import com.concrete.plant.repository.RecheckTaskRepository;
import com.concrete.plant.repository.SampleGroupRepository;
import com.concrete.plant.repository.TestItemRepository;

/**
 * 试块质检闭环：留样登记 → 7/28 天龄期检测 → 复检追溯。
 * 平均值、最小值与判定全部按 Dict 中强度等级设计值在服务端计算，
 * 数据库、接口与前端共用同一判定来源；结果录入与复检生成在同一事务内，
 * 失败整体回滚，不留半条结果、空复检或错误终态。
 */
@Service
public class QualityService {

    private final SampleGroupRepository sampleRepository;
    private final TestItemRepository itemRepository;
    private final RecheckTaskRepository recheckRepository;
    private final ProductionOrderRepository orderRepository;
    private final DispatchTicketRepository ticketRepository;

    public QualityService(SampleGroupRepository sampleRepository, TestItemRepository itemRepository,
                          RecheckTaskRepository recheckRepository, ProductionOrderRepository orderRepository,
                          DispatchTicketRepository ticketRepository) {
        this.sampleRepository = sampleRepository;
        this.itemRepository = itemRepository;
        this.recheckRepository = recheckRepository;
        this.orderRepository = orderRepository;
        this.ticketRepository = ticketRepository;
    }

    // ---------------- 查询 ----------------

    @Transactional(readOnly = true)
    public List<SampleGroupVO> list(String status, String grade, String keyword) {
        List<SampleGroupVO> vos = new ArrayList<>();
        for (SampleGroup group : sampleRepository.findAllOrdered()) {
            if (status != null && !status.isBlank() && !status.equals(group.getStatus())) {
                continue;
            }
            if (grade != null && !grade.isBlank() && !grade.equals(group.getStrengthGrade())) {
                continue;
            }
            if (keyword != null && !keyword.isBlank()) {
                String kw = keyword.trim();
                boolean hit = group.getSampleNo().contains(kw) || group.getProjectName().contains(kw)
                        || group.getOrder().getOrderNo().contains(kw);
                if (!hit) {
                    continue;
                }
            }
            vos.add(toVO(group, true));
        }
        return vos;
    }

    @Transactional(readOnly = true)
    public SampleGroupVO detail(Long id) {
        return toVO(getGroup(id), true);
    }

    /**
     * 待检清单：已到应检日期的 7/28 天检测项（待检/逾期）+ 待复检任务。
     * 已锁定不合格的试块组不再出现（其剩余检测项也不允许再录入）。
     */
    @Transactional(readOnly = true)
    public List<PendingTestVO> pendingList() {
        LocalDate today = LocalDate.now();
        List<PendingTestVO> vos = new ArrayList<>();
        for (TestItem item : itemRepository.findPendingDue(today)) {
            SampleGroup group = item.getSampleGroup();
            if ("UNQUALIFIED".equals(group.getStatus())) {
                continue;
            }
            PendingTestVO vo = basePending(group);
            vo.setKind("ITEM");
            vo.setKindName(item.getAgeDays() + " 天检测");
            vo.setRefId(item.getId());
            vo.setAgeDays(item.getAgeDays());
            vo.setDueDate(item.getDueDate());
            vo.setDisplayStatus(displayStatus(item, today));
            vo.setDisplayStatusName(Dict.itemDisplayStatusName(vo.getDisplayStatus()));
            vos.add(vo);
        }
        for (RecheckTask recheck : recheckRepository.findPending()) {
            SampleGroup group = recheck.getSampleGroup();
            PendingTestVO vo = basePending(group);
            vo.setKind("RECHECK");
            vo.setKindName("复检");
            vo.setRefId(recheck.getId());
            vo.setAgeDays(Dict.FINAL_AGE_DAYS);
            vo.setDueDate(recheck.getCreatedAt().toLocalDate());
            vo.setDisplayStatus("DUE");
            vo.setDisplayStatusName("待复检");
            vos.add(vo);
        }
        return vos;
    }

    /**
     * 任务单视角的完整检测链。
     */
    @Transactional(readOnly = true)
    public OrderQualityChainVO orderChain(Long orderId) {
        ProductionOrder order = orderRepository.findById(orderId)
                .orElseThrow(() -> new BizException("生产任务单不存在：id=" + orderId));
        OrderQualityChainVO vo = new OrderQualityChainVO();
        vo.setOrderId(order.getId());
        vo.setOrderNo(order.getOrderNo());
        vo.setProjectName(order.getProjectName());
        vo.setStrengthGrade(order.getStrengthGrade());
        vo.setOrderStatus(order.getStatus());
        vo.setOrderStatusName(Dict.orderStatusName(order.getStatus()));
        for (SampleGroup group : sampleRepository.findByOrderId(orderId)) {
            vo.getSamples().add(toVO(group, true));
        }
        return vo;
    }

    // ---------------- 留样登记 ----------------

    /**
     * 登记试块组：必须关联同一任务下至少一张已装车的发车单；
     * 快照工程、强度等级与配合比；试块编号唯一约束兜底并发重复提交。
     */
    @Transactional
    public SampleGroupVO register(SampleGroupRequest request) {
        if (request == null) {
            throw new BizException("请求体不能为空");
        }
        if (request.getOrderId() == null) {
            throw new BizException("必须选择生产任务单");
        }
        if (request.getTicketId() == null) {
            throw new BizException("必须关联同一任务下至少一张已装车的发车单");
        }
        if (request.getSampleNo() == null || request.getSampleNo().isBlank()) {
            throw new BizException("试块编号不能为空");
        }
        String sampleNo = request.getSampleNo().trim();
        if (sampleNo.length() > 32) {
            throw new BizException("试块编号长度不能超过 32 位");
        }
        if (request.getSampleTime() == null) {
            throw new BizException("取样时间不能为空");
        }
        LocalDateTime now = LocalDateTime.now();
        if (request.getSampleTime().isAfter(now)) {
            throw new BizException("取样时间不能晚于当前时间");
        }
        if (!Dict.isValidCuringMethod(request.getCuringMethod())) {
            throw new BizException("未知的养护方式：" + request.getCuringMethod());
        }
        if (request.getInspector() == null || request.getInspector().isBlank()) {
            throw new BizException("登记质检员不能为空");
        }

        ProductionOrder order = orderRepository.findById(request.getOrderId())
                .orElseThrow(() -> new BizException("生产任务单不存在：id=" + request.getOrderId()));
        DispatchTicket ticket = ticketRepository.findById(request.getTicketId())
                .orElseThrow(() -> new BizException("发车单不存在：id=" + request.getTicketId()));
        if (!ticket.getOrder().getId().equals(order.getId())) {
            throw new BizException("发车单 " + ticket.getTicketNo() + " 不属于任务单 " + order.getOrderNo()
                    + "，试块必须关联同一任务下的发车单");
        }
        if (ticket.getLoadTime() == null) {
            throw new BizException("发车单 " + ticket.getTicketNo() + " 尚未装车，不能作为留样依据");
        }
        if (sampleRepository.findBySampleNo(sampleNo).isPresent()) {
            throw new BizException("试块编号 " + sampleNo + " 已登记，请勿重复提交");
        }

        SampleGroup group = new SampleGroup();
        group.setGroupNo("SG-" + sampleNo);
        group.setSampleNo(sampleNo);
        group.setOrder(order);
        group.setTicket(ticket);
        group.setSampleTime(request.getSampleTime());
        group.setCuringMethod(request.getCuringMethod());
        group.setInspector(request.getInspector().trim());
        group.setProjectName(order.getProjectName());
        group.setStrengthGrade(order.getStrengthGrade());
        group.setMixSnapshot(mixSnapshot(order));
        group.setStatus("TESTING");
        group.setCreatedAt(now);
        for (Integer age : Dict.TEST_AGES) {
            TestItem item = new TestItem();
            item.setAgeDays(age);
            item.setDueDate(request.getSampleTime().toLocalDate().plusDays(age));
            item.setStatus("PENDING");
            group.addItem(item);
        }
        try {
            sampleRepository.saveAndFlush(group);
        } catch (DataIntegrityViolationException e) {
            // 并发登记同一试块编号：唯一约束只放行一个，其余在这里得到明确提示
            throw new BizException("试块编号 " + sampleNo + " 已登记，请勿重复提交");
        }
        return toVO(group, true);
    }

    // ---------------- 结果录入 ----------------

    /**
     * 录入龄期检测结果：行级悲观锁保证两个质检员同时提交同一待检项时，
     * 后到请求看到状态已变化；未到目标龄期不得录入；原始读数落库后不可覆盖。
     * 28 天未达门槛时同事务生成唯一复检任务。
     */
    @Transactional
    public SampleGroupVO submitItemResult(Long itemId, TestResultRequest request) {
        TestItem item = itemRepository.findByIdForUpdate(itemId)
                .orElseThrow(() -> new BizException("检测项不存在：id=" + itemId));
        SampleGroup group = item.getSampleGroup();
        if (!"PENDING".equals(item.getStatus())) {
            throw new BizException("该检测项已由 " + item.getTestedBy() + " 于 " + item.getTestedAt()
                    + " 录入，状态已变化，请刷新后查看");
        }
        if ("UNQUALIFIED".equals(group.getStatus())) {
            throw new BizException("试块组 " + group.getSampleNo() + " 已锁定为不合格，不能再录入检测结果");
        }
        LocalDate today = LocalDate.now();
        if (today.isBefore(item.getDueDate())) {
            throw new BizException("未到 " + item.getAgeDays() + " 天目标龄期（应检日期 " + item.getDueDate()
                    + "），不得录入正式结果");
        }
        applyResult(request);

        BigDecimal avg = avgOf(request);
        BigDecimal min = minOf(request);
        boolean finalAge = item.getAgeDays() == Dict.FINAL_AGE_DAYS;
        String verdict = finalAge
                ? Dict.judgeFinal(group.getStrengthGrade(), avg, min)
                : Dict.judgeTrend(group.getStrengthGrade(), avg);
        item.setStrength1(request.getStrength1());
        item.setStrength2(request.getStrength2());
        item.setStrength3(request.getStrength3());
        item.setAvgStrength(avg);
        item.setMinStrength(min);
        item.setVerdict(verdict);
        item.setTestedBy(request.getTestedBy().trim());
        item.setTestedAt(LocalDateTime.now());
        item.setStatus("DONE");
        itemRepository.save(item);

        if (finalAge) {
            if ("PASS".equals(verdict)) {
                group.setStatus("QUALIFIED");
            } else {
                // 28 天未达门槛：同事务生成唯一复检任务（origin_item_id 唯一约束兜底并发）
                group.setStatus("RECHECKING");
                RecheckTask recheck = new RecheckTask();
                recheck.setRecheckNo("RH-" + group.getSampleNo());
                recheck.setSampleGroup(group);
                recheck.setOriginItem(item);
                recheck.setStatus("PENDING");
                recheck.setCreatedAt(LocalDateTime.now());
                recheckRepository.save(recheck);
            }
            sampleRepository.save(group);
        }
        // 7 天结果只展示趋势，不改变试块组质量状态
        return toVO(group, true);
    }

    /**
     * 录入复检结果：必须引用原复检任务；复检合格试块组才转合格，仍失败则锁定不合格。
     */
    @Transactional
    public SampleGroupVO submitRecheckResult(Long recheckId, TestResultRequest request) {
        RecheckTask recheck = recheckRepository.findByIdForUpdate(recheckId)
                .orElseThrow(() -> new BizException("复检任务不存在：id=" + recheckId));
        if (!"PENDING".equals(recheck.getStatus())) {
            throw new BizException("该复检任务已由 " + recheck.getTestedBy() + " 于 " + recheck.getTestedAt()
                    + " 录入，状态已变化，请刷新后查看");
        }
        SampleGroup group = recheck.getSampleGroup();
        if (!"RECHECKING".equals(group.getStatus())) {
            throw new BizException("试块组当前状态为「" + Dict.sampleStatusName(group.getStatus())
                    + "」，不能录入复检结果");
        }
        applyResult(request);

        BigDecimal avg = avgOf(request);
        BigDecimal min = minOf(request);
        String verdict = Dict.judgeFinal(group.getStrengthGrade(), avg, min);
        recheck.setStrength1(request.getStrength1());
        recheck.setStrength2(request.getStrength2());
        recheck.setStrength3(request.getStrength3());
        recheck.setAvgStrength(avg);
        recheck.setMinStrength(min);
        recheck.setVerdict(verdict);
        recheck.setTestedBy(request.getTestedBy().trim());
        recheck.setTestedAt(LocalDateTime.now());
        recheck.setStatus("DONE");
        recheckRepository.save(recheck);

        group.setStatus("PASS".equals(verdict) ? "QUALIFIED" : "UNQUALIFIED");
        sampleRepository.save(group);
        return toVO(group, true);
    }

    // ---------------- 内部校验与计算 ----------------

    private void applyResult(TestResultRequest request) {
        if (request == null) {
            throw new BizException("请求体不能为空");
        }
        BigDecimal[] strengths = {request.getStrength1(), request.getStrength2(), request.getStrength3()};
        for (int i = 0; i < strengths.length; i++) {
            if (strengths[i] == null) {
                throw new BizException("第 " + (i + 1) + " 块抗压强度不能为空");
            }
            if (strengths[i].compareTo(BigDecimal.ZERO) <= 0
                    || strengths[i].compareTo(Dict.MAX_STRENGTH) > 0) {
                throw new BizException("第 " + (i + 1) + " 块抗压强度 " + strengths[i]
                        + " MPa 超出合理范围（0 ~ " + Dict.MAX_STRENGTH + " MPa）");
            }
        }
        if (request.getTestedBy() == null || request.getTestedBy().isBlank()) {
            throw new BizException("检测人不能为空");
        }
    }

    private BigDecimal avgOf(TestResultRequest request) {
        return request.getStrength1().add(request.getStrength2()).add(request.getStrength3())
                .divide(BigDecimal.valueOf(3), 2, RoundingMode.HALF_UP);
    }

    private BigDecimal minOf(TestResultRequest request) {
        return request.getStrength1().min(request.getStrength2()).min(request.getStrength3());
    }

    /** 检测项页面展示状态：已检 / 未到期 / 待检 / 逾期（由应检日期推导，不落库） */
    private String displayStatus(TestItem item, LocalDate today) {
        if ("DONE".equals(item.getStatus())) {
            return "DONE";
        }
        if (today.isBefore(item.getDueDate())) {
            return "NOT_DUE";
        }
        if (today.isAfter(item.getDueDate().plusDays(Dict.OVERDUE_GRACE_DAYS))) {
            return "OVERDUE";
        }
        return "DUE";
    }

    private SampleGroup getGroup(Long id) {
        return sampleRepository.findById(id).orElseThrow(() -> new BizException("试块组不存在：id=" + id));
    }

    /** 配合比快照：登记时冻结，之后任务单配合比调整不影响已留样试块 */
    private String mixSnapshot(ProductionOrder order) {
        StringBuilder sb = new StringBuilder("[");
        boolean first = true;
        for (MixRatioItem item : order.getItems()) {
            if (!first) {
                sb.append(',');
            }
            sb.append("{\"material\":\"").append(item.getMaterialName())
                    .append("\",\"dosage\":").append(item.getDosage()).append('}');
            first = false;
        }
        return sb.append(']').toString();
    }

    private PendingTestVO basePending(SampleGroup group) {
        PendingTestVO vo = new PendingTestVO();
        vo.setSampleId(group.getId());
        vo.setSampleNo(group.getSampleNo());
        vo.setProjectName(group.getProjectName());
        vo.setStrengthGrade(group.getStrengthGrade());
        return vo;
    }

    // ---------------- VO 映射 ----------------

    private SampleGroupVO toVO(SampleGroup group, boolean withItems) {
        LocalDate today = LocalDate.now();
        SampleGroupVO vo = new SampleGroupVO();
        vo.setId(group.getId());
        vo.setGroupNo(group.getGroupNo());
        vo.setSampleNo(group.getSampleNo());
        vo.setSampleTime(group.getSampleTime());
        vo.setCuringMethod(group.getCuringMethod());
        vo.setCuringMethodName(Dict.curingMethodName(group.getCuringMethod()));
        vo.setInspector(group.getInspector());
        vo.setProjectName(group.getProjectName());
        vo.setStrengthGrade(group.getStrengthGrade());
        vo.setMixSnapshot(group.getMixSnapshot());
        vo.setStatus(group.getStatus());
        vo.setStatusName(Dict.sampleStatusName(group.getStatus()));
        vo.setCreatedAt(group.getCreatedAt());
        if (group.getOrder() != null) {
            vo.setOrderId(group.getOrder().getId());
            vo.setOrderNo(group.getOrder().getOrderNo());
        }
        if (group.getTicket() != null) {
            vo.setTicketId(group.getTicket().getId());
            vo.setTicketNo(group.getTicket().getTicketNo());
        }
        if (withItems) {
            for (TestItem item : itemRepository.findBySampleGroupId(group.getId())) {
                vo.getItems().add(toItemVO(item, group.getStrengthGrade(), today));
            }
            List<RecheckTask> rechecks = recheckRepository.findBySampleGroupId(group.getId());
            if (!rechecks.isEmpty()) {
                vo.setRecheck(toRecheckVO(rechecks.get(0), group.getStrengthGrade()));
            }
        }
        return vo;
    }

    private TestItemVO toItemVO(TestItem item, String grade, LocalDate today) {
        TestItemVO vo = new TestItemVO();
        vo.setId(item.getId());
        vo.setAgeDays(item.getAgeDays());
        vo.setDueDate(item.getDueDate());
        vo.setStatus(item.getStatus());
        vo.setDisplayStatus(displayStatus(item, today));
        vo.setDisplayStatusName(Dict.itemDisplayStatusName(vo.getDisplayStatus()));
        vo.setStrength1(item.getStrength1());
        vo.setStrength2(item.getStrength2());
        vo.setStrength3(item.getStrength3());
        vo.setAvgStrength(item.getAvgStrength());
        vo.setMinStrength(item.getMinStrength());
        vo.setVerdict(item.getVerdict());
        vo.setVerdictName(verdictName(item.getAgeDays(), item.getVerdict()));
        vo.setTestedBy(item.getTestedBy());
        vo.setTestedAt(item.getTestedAt());
        vo.setDesignStrength(Dict.designStrength(grade));
        vo.setAvgThreshold(Dict.avgThreshold(grade));
        vo.setMinThreshold(Dict.minThreshold(grade));
        vo.setTrendReference(Dict.trendReference(grade));
        return vo;
    }

    private RecheckTaskVO toRecheckVO(RecheckTask recheck, String grade) {
        RecheckTaskVO vo = new RecheckTaskVO();
        vo.setId(recheck.getId());
        vo.setRecheckNo(recheck.getRecheckNo());
        if (recheck.getOriginItem() != null) {
            vo.setOriginItemId(recheck.getOriginItem().getId());
        }
        vo.setStatus(recheck.getStatus());
        vo.setStatusName("DONE".equals(recheck.getStatus()) ? "已复检" : "待复检");
        vo.setStrength1(recheck.getStrength1());
        vo.setStrength2(recheck.getStrength2());
        vo.setStrength3(recheck.getStrength3());
        vo.setAvgStrength(recheck.getAvgStrength());
        vo.setMinStrength(recheck.getMinStrength());
        vo.setVerdict(recheck.getVerdict());
        vo.setVerdictName(verdictName(Dict.FINAL_AGE_DAYS, recheck.getVerdict()));
        vo.setTestedBy(recheck.getTestedBy());
        vo.setTestedAt(recheck.getTestedAt());
        vo.setCreatedAt(recheck.getCreatedAt());
        vo.setAvgThreshold(Dict.avgThreshold(grade));
        vo.setMinThreshold(Dict.minThreshold(grade));
        return vo;
    }

    private String verdictName(Integer ageDays, String verdict) {
        if (verdict == null) {
            return null;
        }
        boolean trend = ageDays != null && ageDays != Dict.FINAL_AGE_DAYS;
        if ("PASS".equals(verdict)) {
            return trend ? "趋势正常" : "合格";
        }
        return trend ? "趋势偏低" : "不合格";
    }
}
