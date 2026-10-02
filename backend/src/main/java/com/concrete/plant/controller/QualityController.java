package com.concrete.plant.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.concrete.plant.common.ApiResponse;
import com.concrete.plant.dto.OrderQualityChainVO;
import com.concrete.plant.dto.PendingTestVO;
import com.concrete.plant.dto.SampleGroupRequest;
import com.concrete.plant.dto.SampleGroupVO;
import com.concrete.plant.dto.TestResultRequest;
import com.concrete.plant.service.QualityService;

/**
 * 试块质检：留样登记、龄期检测、复检追溯。
 * 判定（平均值/最小值/合格与否）全部在服务端完成，前端只提交三块原始读数。
 */
@RestController
@RequestMapping("/api/quality")
public class QualityController {

    private final QualityService qualityService;

    public QualityController(QualityService qualityService) {
        this.qualityService = qualityService;
    }

    @GetMapping("/samples")
    public ApiResponse<List<SampleGroupVO>> list(@RequestParam(required = false) String status,
                                                 @RequestParam(required = false) String grade,
                                                 @RequestParam(required = false) String keyword) {
        return ApiResponse.success(qualityService.list(status, grade, keyword));
    }

    @PostMapping("/samples")
    public ApiResponse<SampleGroupVO> register(@RequestBody SampleGroupRequest request) {
        return ApiResponse.success("试块组已登记，7 天 / 28 天检测项已生成", qualityService.register(request));
    }

    @GetMapping("/samples/{id}")
    public ApiResponse<SampleGroupVO> detail(@PathVariable Long id) {
        return ApiResponse.success(qualityService.detail(id));
    }

    @GetMapping("/pending")
    public ApiResponse<List<PendingTestVO>> pending() {
        return ApiResponse.success(qualityService.pendingList());
    }

    /** 录入检测项三块抗压强度（服务端统一计算与判定） */
    @PostMapping("/items/{id}/result")
    public ApiResponse<SampleGroupVO> submitItemResult(@PathVariable Long id,
                                                       @RequestBody TestResultRequest request) {
        return ApiResponse.success("检测结果已录入", qualityService.submitItemResult(id, request));
    }

    /** 录入复检结果（引用原检测，保留操作者与时间） */
    @PostMapping("/rechecks/{id}/result")
    public ApiResponse<SampleGroupVO> submitRecheckResult(@PathVariable Long id,
                                                          @RequestBody TestResultRequest request) {
        return ApiResponse.success("复检结果已录入", qualityService.submitRecheckResult(id, request));
    }

    /** 任务单视角的完整检测链 */
    @GetMapping("/orders/{orderId}/chain")
    public ApiResponse<OrderQualityChainVO> orderChain(@PathVariable Long orderId) {
        return ApiResponse.success(qualityService.orderChain(orderId));
    }
}
