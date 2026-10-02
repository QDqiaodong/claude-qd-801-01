package com.concrete.plant.repository;

import java.util.List;
import java.util.Optional;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.concrete.plant.domain.RecheckTask;

public interface RecheckTaskRepository extends JpaRepository<RecheckTask, Long> {

    /** 录入复检结果时行级加锁，后到请求看到状态已变化 */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from RecheckTask r where r.id = :id")
    Optional<RecheckTask> findByIdForUpdate(@Param("id") Long id);

    @Query("select r from RecheckTask r where r.sampleGroup.id = :sampleId order by r.id desc")
    List<RecheckTask> findBySampleGroupId(@Param("sampleId") Long sampleId);

    /** 待复检清单 */
    @Query("select r from RecheckTask r join fetch r.sampleGroup g "
            + "where r.status = 'PENDING' order by r.createdAt asc, r.id asc")
    List<RecheckTask> findPending();
}
