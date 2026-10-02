package com.concrete.plant.repository;

import java.math.BigDecimal;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.concrete.plant.domain.DispatchTicket;
import com.concrete.plant.dto.SiteDeliveryVO;

public interface DispatchTicketRepository extends JpaRepository<DispatchTicket, Long> {

    @Query("select t from DispatchTicket t order by t.loadTime desc, t.id desc")
    List<DispatchTicket> findAllOrdered();

    @Query("select t from DispatchTicket t where t.order.id = :orderId order by t.loadTime")
    List<DispatchTicket> findByOrderId(@Param("orderId") Long orderId);

    @Query("select t from DispatchTicket t where t.truck.id = :truckId order by t.loadTime desc")
    List<DispatchTicket> findByTruckId(@Param("truckId") Long truckId);

    /**
     * 手写 JPQL 四：按工地汇总发货量（只统计已签收）。
     */
    @Query("select new com.concrete.plant.dto.SiteDeliveryVO(t.order.projectName, sum(t.signVolume), count(t)) "
            + "from DispatchTicket t where t.status = 'SIGNED' "
            + "group by t.order.projectName order by sum(t.signVolume) desc")
    List<SiteDeliveryVO> statBySite();

    @Query("select sum(t.signVolume) from DispatchTicket t where t.order.id = :orderId")
    BigDecimal sumSignedByOrder(@Param("orderId") Long orderId);

    @Query("select count(t) from DispatchTicket t where t.status = 'SIGNED'")
    long countSigned();

    @Query("select count(t) from DispatchTicket t where t.order.id = :orderId")
    long countByOrderId(@Param("orderId") Long orderId);
}
