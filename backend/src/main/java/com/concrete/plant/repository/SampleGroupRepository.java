package com.concrete.plant.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.concrete.plant.domain.SampleGroup;

public interface SampleGroupRepository extends JpaRepository<SampleGroup, Long> {

    Optional<SampleGroup> findBySampleNo(String sampleNo);

    @Query("select g from SampleGroup g order by g.createdAt desc, g.id desc")
    List<SampleGroup> findAllOrdered();

    @Query("select g from SampleGroup g where g.order.id = :orderId order by g.createdAt desc, g.id desc")
    List<SampleGroup> findByOrderId(@Param("orderId") Long orderId);
}
