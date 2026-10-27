package com.myaaptha.domain.auth;
import com.myaaptha.domain.user.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

@RestController @RequestMapping("/api/auth")
public class PhoneVerificationController {
 private final PhoneVerificationService verification;private final UserRepository users;private final AuthTokenRepository tokens;private final PasswordEncoder encoder;
 public PhoneVerificationController(PhoneVerificationService verification,UserRepository users,AuthTokenRepository tokens,PasswordEncoder encoder){this.verification=verification;this.users=users;this.tokens=tokens;this.encoder=encoder;}
 public record SecurityPolicy(boolean phoneVerificationRequired,boolean phoneVerificationConfigured,String phoneVerificationUrl){}
 @GetMapping("/security-policy") public SecurityPolicy policy(){return new SecurityPolicy(verification.required(),verification.configured(),verification.verificationUrl());}
 @PostMapping("/phone/start") public ResponseEntity<Void> start(@Valid @RequestBody Start body,HttpServletRequest request){verification.start(body.phoneNumber(),body.captchaToken(),request.getRemoteAddr());return ResponseEntity.accepted().build();}
 @PostMapping("/reset-password") @Transactional public ResponseEntity<Void> reset(@Valid @RequestBody Reset body){
   if(!body.password().matches(".*[A-Za-z].*")||!body.password().matches(".*[0-9].*"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Use letters and numbers in your password");
   String phone=verification.normalize(body.phoneNumber());if(!verification.verify(phone,body.verificationCode()))throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Verified recovery is not configured");
   var user=users.findByPhoneNumber(phone).orElse(null);
   if(user!=null&&"ACTIVE".equals(user.getAccountStatus())&&!"ADMIN".equals(user.getRole())){user.setPasswordHash(encoder.encode(body.password()));user.setPhoneVerified(true);users.save(user);tokens.deleteByUserIdAndTokenType(user.getId(),"refresh");}
   return ResponseEntity.noContent().build();
 }
 public record Start(@NotBlank @Size(max=32) String phoneNumber,@NotBlank @Size(max=2048) String captchaToken){}
 public record Reset(@NotBlank @Size(max=32) String phoneNumber,@NotBlank @Pattern(regexp="[0-9]{4,10}") String verificationCode,@NotBlank @Size(min=8,max=128) String password){}
}
