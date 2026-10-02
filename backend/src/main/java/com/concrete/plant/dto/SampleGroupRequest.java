package com.concrete.plant.dto;

import java.time.LocalDateTime;

import lombok.Getter;
import lombok.Setter;

/**
 * 试块组留样登记请求体。
 */
@Getter
@Setter
public class SampleGroupRequest {

    private Long orderId;
    private Long ticketId;
    private String sampleNo;
    private LocalDateTime sampleTime;
    private String curingMethod;
    private String inspector;
}
