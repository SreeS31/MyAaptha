package com.myaaptha.domain.auth;

import com.myaaptha.domain.user.model.UserEntity;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.Instant;
import java.util.*;
import javax.crypto.*;
import javax.crypto.spec.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class AdminMfaService {
 private final JdbcTemplate jdbc;private final boolean required;private final String key;
 public AdminMfaService(JdbcTemplate jdbc,@Value("${security.admin-mfa.required:false}") boolean required,@Value("${ADMIN_MFA_ENCRYPTION_KEY:}") String key){this.jdbc=jdbc;this.required=required;this.key=key;}
 public void verify(UserEntity user,String code){
   if(!required||!"ADMIN".equals(user.getRole()))return;
   if(code==null||!code.matches("[0-9]{6}"))throw new IllegalArgumentException("Authenticator code required");
   var values=jdbc.queryForList("SELECT encrypted_secret FROM admin_mfa WHERE user_id=?",String.class,user.getId());
   if(values.isEmpty())throw new IllegalArgumentException("Administrator MFA enrollment is required");
   byte[] secret=decrypt(values.getFirst(),key,user.getId());long current=Instant.now().getEpochSecond()/30;
   for(long step=current-1;step<=current+1;step++)if(MessageDigest.isEqual(totp(secret,step).getBytes(StandardCharsets.US_ASCII),code.getBytes(StandardCharsets.US_ASCII))){
     if(jdbc.update("UPDATE admin_mfa SET last_counter=? WHERE user_id=? AND last_counter<?",step,user.getId(),step)==1)return;
     break;
   }
   throw new IllegalArgumentException("Authenticator code is invalid or already used");
 }
 public static String totp(byte[] secret,long counter){try{var mac=Mac.getInstance("HmacSHA1");mac.init(new SecretKeySpec(secret,"HmacSHA1"));byte[] digest=mac.doFinal(ByteBuffer.allocate(8).putLong(counter).array());int offset=digest[digest.length-1]&15;int value=ByteBuffer.wrap(digest,offset,4).getInt()&0x7fffffff;return String.format(Locale.ROOT,"%06d",value%1000000);}catch(GeneralSecurityException error){throw new IllegalStateException("MFA unavailable",error);}}
 public static String encrypt(byte[] secret,String key,long userId){try{byte[] nonce=new byte[12];new SecureRandom().nextBytes(nonce);var cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,new SecretKeySpec(decodeKey(key),"AES"),new GCMParameterSpec(128,nonce));cipher.updateAAD(Long.toString(userId).getBytes(StandardCharsets.US_ASCII));byte[] encrypted=cipher.doFinal(secret);return Base64.getEncoder().encodeToString(ByteBuffer.allocate(nonce.length+encrypted.length).put(nonce).put(encrypted).array());}catch(GeneralSecurityException error){throw new IllegalStateException("MFA encryption unavailable",error);}}
 public static byte[] decrypt(String value,String key,long userId){try{byte[] bytes=Base64.getDecoder().decode(value);if(bytes.length<29)throw new GeneralSecurityException();var cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,new SecretKeySpec(decodeKey(key),"AES"),new GCMParameterSpec(128,Arrays.copyOf(bytes,12)));cipher.updateAAD(Long.toString(userId).getBytes(StandardCharsets.US_ASCII));return cipher.doFinal(Arrays.copyOfRange(bytes,12,bytes.length));}catch(GeneralSecurityException|IllegalArgumentException error){throw new IllegalStateException("MFA secret unavailable");}}
 private static byte[] decodeKey(String key){byte[] bytes=Base64.getDecoder().decode(key);if(bytes.length!=32)throw new IllegalArgumentException("MFA encryption key must be 32 random bytes encoded as Base64");return bytes;}
 public static String base32(byte[] bytes){String alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";var result=new StringBuilder();int bits=0,value=0;for(byte item:bytes){value=(value<<8)|(item&255);bits+=8;while(bits>=5){result.append(alphabet.charAt((value>>>(bits-5))&31));bits-=5;}}if(bits>0)result.append(alphabet.charAt((value<<(5-bits))&31));return result.toString();}
}
