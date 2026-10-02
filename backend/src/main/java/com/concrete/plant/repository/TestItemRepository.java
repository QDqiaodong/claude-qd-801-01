package com.concrete.plant.repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.concrete.plant.domain.TestItem;

public interface TestItemRepository extends JpaRepository<TestItem, Long> {

    /**
     * 录入结果时行级加锁：两个质检员同时提交同一待检项，
     * 后到请求阻塞到前一事务提交后读到 DONE 状态，被业务校验拦下。
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select i from TestItem i where i.id = :id")
    Optional<TestItem> findByIdForUpdate(@Param("id") Long id);

    @Query("select i from TestItem i where i.sampleGroup.id = :sampleId order by i.ageDays asc")
    List<TestItem> findBySampleGroupId(@Param("sampleId") Long sampleId);

    /** 待检清单：已到应检日期仍未录入的检测项（含待检与逾期，页面状态由服务端推导） */
    @Query("select i from TestItem i join fetch i.sampleGroup g "
            + "where i.status = 'PENDING' and i.dueDate <= :today order by i.dueDate asc, i.id asc")
    List<TestItem> findPendingDue(@Param("today") LocalDate today);
}
