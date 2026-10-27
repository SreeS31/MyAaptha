package com.myaaptha.domain.contacts;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.security.Principal;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/address-book")
public class AddressBookController {
  private final AddressBookService book;
  private final com.myaaptha.domain.ai.ContactOAuthService oauth;
  private final AddressBookImportService importer;
  private final AddressBookCircleService circles;
  public AddressBookController(AddressBookService book,com.myaaptha.domain.ai.ContactOAuthService oauth,AddressBookImportService importer,AddressBookCircleService circles) { this.book = book;this.oauth=oauth;this.importer=importer;this.circles=circles; }

  public record ProviderRequest(@AssertTrue boolean consent,@NotBlank @Email String email,@Pattern(regexp="google|microsoft") @NotNull String provider,boolean organize) {}
  @GetMapping("/providers")
  public java.util.Map<String,Boolean> providers(){return oauth.availability();}
  @PostMapping("/oauth/start")
  public com.myaaptha.domain.ai.ContactOAuthService.StartResult start(Principal principal,@Valid @RequestBody ProviderRequest request) {
    return oauth.startAddressBook(Long.valueOf(principal.getName()),new com.myaaptha.domain.ai.ContactOAuthService.StartRequest(request.email(),request.provider()),request.organize());
  }
  @GetMapping("/oauth/results/{key}")
  public Object result(Principal principal,@PathVariable String key){return oauth.consume(Long.valueOf(principal.getName()),key);}

  public record ContactInput(@Size(max=200) String displayName,
      @Size(max=20) List<@NotNull @Size(max=80) String> phones,
      @Size(max=20) List<@NotNull @Size(max=254) String> emails,
      @Size(max=300) String organization,@Size(max=20) List<@NotBlank @Size(max=100) String> groups) {}
  public record ImportRequest(@AssertTrue(message="Allow saving contacts to your private address book") boolean consent,
      @NotNull @Size(min=1,max=100) List<@NotNull @Valid ContactInput> contacts,
      @NotNull @Pattern(regexp="device|csv|vcard|google|microsoft") String source,boolean organize) {}
  public record RelationRequest(@AssertTrue(message="Confirm adding this contact as a relation") boolean consent,
      @NotBlank @Size(max=80) String relationship, @Size(max=80) String phone) {}

  public record ReviewedContact(@NotNull @Valid ContactInput contact,
      @NotNull @Size(max=20) List<@NotBlank @Size(max=100) String> circleNames) {}
  public record ReviewedImport(@AssertTrue boolean consent,
      @NotNull @Size(min=1,max=100) List<@NotNull @Valid ReviewedContact> contacts,
      @NotNull @Pattern(regexp="device|csv|vcard|google|microsoft") String source) {}
  @PostMapping("/import-reviewed")
  public Object reviewed(Principal principal,@Valid @RequestBody ReviewedImport request) {
    return importer.saveReviewed(Long.valueOf(principal.getName()),request.contacts(),request.source());
  }

  @PostMapping("/import")
  public AddressBookImportService.Outcome save(Principal principal, @Valid @RequestBody ImportRequest request) {
    return importer.save(Long.valueOf(principal.getName()),request.contacts(),request.source(),request.organize());
  }
  @GetMapping
  public AddressBookService.Page list(Principal principal, @RequestParam(defaultValue="0") long afterId,
      @RequestParam(defaultValue="50") int limit, @RequestParam(defaultValue="") String q,@RequestParam(required=false) Long circleId) {
    return book.list(Long.valueOf(principal.getName()),afterId,limit,q,circleId);
  }
  @GetMapping("/circles") public List<AddressBookCircleService.Circle> circles(Principal principal){return circles.list(Long.valueOf(principal.getName()));}
  public record CircleSelection(@NotNull @Size(max=20) List<@Positive Long> circleIds){}
  @PutMapping("/{id}/circles") public void assign(Principal principal,@PathVariable long id,@Valid @RequestBody CircleSelection request){circles.assign(Long.valueOf(principal.getName()),id,request.circleIds());}
  @DeleteMapping("/{id}")
  public void delete(Principal principal,@PathVariable long id) { book.delete(Long.valueOf(principal.getName()),id); }
  @DeleteMapping
  public void clear(Principal principal,@RequestParam(defaultValue="false") boolean confirm) {
    book.clear(Long.valueOf(principal.getName()),confirm);
  }
  @PostMapping("/{id}/relation")
  public AddressBookService.Entry relation(Principal principal,@PathVariable long id,@Valid @RequestBody RelationRequest request) {
    return book.relate(Long.valueOf(principal.getName()),id,request);
  }
}
