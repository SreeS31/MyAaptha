package com.myaaptha.domain.finance;

import java.security.Principal;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.springframework.core.io.Resource;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/finance/renewals")
public class RenewalController {
  private final RenewalService service;
  public RenewalController(RenewalService service){this.service=service;}
  @GetMapping public List<RenewalService.Item> list(Principal p){return service.list(id(p));}
  @PostMapping @ResponseStatus(HttpStatus.CREATED)
  public RenewalService.Item create(Principal p,@RequestBody RenewalService.Input input){return service.create(id(p),input);}
  @PutMapping("/{id}") public RenewalService.Item update(Principal p,@PathVariable long id,@RequestBody RenewalService.Input input){return service.update(id(p),id,input);}
  @PutMapping("/{id}/state") public RenewalService.Item state(Principal p,@PathVariable long id,@RequestBody RenewalService.State state){return service.state(id(p),id,state);}
  @DeleteMapping("/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void delete(Principal p,@PathVariable long id){service.delete(id(p),id);}
  @PostMapping(value="/{id}/attachment",consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
  public RenewalService.Item attach(Principal p,@PathVariable long id,@RequestParam("file") MultipartFile file){return service.attach(id(p),id,file);}
  @DeleteMapping("/{id}/attachment") @ResponseStatus(HttpStatus.NO_CONTENT)
  public void removeAttachment(Principal p,@PathVariable long id){service.removeAttachment(id(p),id);}
  @GetMapping("/{id}/attachment") public ResponseEntity<Resource> attachment(Principal p,@PathVariable long id){
    var a=service.attachment(id(p),id);
    return ResponseEntity.ok().cacheControl(CacheControl.noStore()).header("X-Content-Type-Options","nosniff")
        .header(HttpHeaders.CONTENT_DISPOSITION,ContentDisposition.attachment().filename(a.name(),StandardCharsets.UTF_8).build().toString())
        .contentType(MediaType.parseMediaType(a.type())).body(a.resource());
  }
  private long id(Principal principal){return Long.parseLong(principal.getName());}
}
