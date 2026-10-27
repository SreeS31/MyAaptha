package com.myaaptha.platform.security;
import com.myaaptha.platform.media.ClamAvMediaScanner;
import com.myaaptha.platform.media.MediaScanner;
import java.util.*;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/admin/security")
public class SecurityReportsController {
 private final SecurityIncidentService incidents;private final SecurityAlertDispatcher alerts;private final MediaScanner scanner;
 public SecurityReportsController(SecurityIncidentService incidents,SecurityAlertDispatcher alerts,MediaScanner scanner){this.incidents=incidents;this.alerts=alerts;this.scanner=scanner;}
 @GetMapping public Map<String,Object> list(@RequestParam(defaultValue="0")int page){boolean ready=false;if(scanner instanceof ClamAvMediaScanner clam)try{clam.assertFresh();ready=true;}catch(Exception ignored){}return Map.of("items",incidents.list(page),"antivirusReady",ready,"emailConfigured",alerts.configured(),"blockMinutes",60);}
 @PostMapping("/{id}/resolve") public void resolve(@PathVariable long id){incidents.resolve(id);}
 @PostMapping("/{id}/unblock") public void unblock(@PathVariable long id){incidents.unblock(id);}
}
