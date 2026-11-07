package com.myaaptha.platform.media;
import org.springframework.boot.health.contributor.*;
import org.springframework.stereotype.Component;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
@Component("clamavHealthIndicator") @ConditionalOnProperty(name="myaaptha.storage.scanner",havingValue="clamav")
public class ClamavHealthIndicator implements HealthIndicator{
 private final ClamAvMediaScanner scanner;public ClamavHealthIndicator(ClamAvMediaScanner scanner){this.scanner=scanner;}
 public Health health(){try{scanner.assertFresh();return Health.up().build();}catch(Exception error){return Health.down().build();}}
}
