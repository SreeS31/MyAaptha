package com.myaaptha.platform.audit; import org.springframework.data.jpa.repository.JpaRepository; public interface AuditEventRepository extends JpaRepository<AuditEventEntity,Long>{}
