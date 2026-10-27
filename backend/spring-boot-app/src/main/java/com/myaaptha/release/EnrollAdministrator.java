package com.myaaptha.release;

import com.myaaptha.domain.auth.AdminMfaService;
import java.sql.*;
import java.security.SecureRandom;

/** Run only from a protected operator console; never put its output in CI logs. */
public class EnrollAdministrator {
 public static void main(String[] args)throws Exception{
   if(args.length!=1||System.console()==null)throw new IllegalArgumentException("Use a protected interactive console: EnrollAdministrator <verified-username>");
   String password=System.getenv("POSTGRES_PASSWORD"),key=System.getenv("ADMIN_MFA_ENCRYPTION_KEY");
   String url="jdbc:postgresql://"+System.getenv("POSTGRES_HOST")+":"+System.getenv().getOrDefault("POSTGRES_PORT","5432")+"/"+System.getenv().getOrDefault("POSTGRES_DB","myaaptha")+"?sslmode=verify-full";
   try(var connection=DriverManager.getConnection(url,System.getenv().getOrDefault("POSTGRES_USER","myaaptha"),password)){
     connection.setAutoCommit(false);
     long id;try(var query=connection.prepareStatement("SELECT id FROM users WHERE username=? AND phone_verified=TRUE AND account_status='ACTIVE' FOR UPDATE")){query.setString(1,args[0]);try(var rows=query.executeQuery()){if(!rows.next())throw new IllegalArgumentException("Verified active account required");id=rows.getLong(1);}}
     if(!"ENROLL".equals(System.console().readLine("Grant administrator access and revoke existing sessions for %s? Type ENROLL: ",args[0])))return;
     byte[] secret=new byte[20];new SecureRandom().nextBytes(secret);String encrypted=AdminMfaService.encrypt(secret,key,id);
     System.console().printf("Add this secret to your authenticator in a private setting: %s%n",AdminMfaService.base32(secret));
     String code=System.console().readLine("Enter the current six-digit authenticator code: ");
     if(!AdminMfaService.totp(secret,java.time.Instant.now().getEpochSecond()/30).equals(code))throw new IllegalArgumentException("Enrollment confirmation failed; nothing changed");
     try(var upsert=connection.prepareStatement("INSERT INTO admin_mfa(user_id,encrypted_secret,last_counter) VALUES (?,?,-1) ON CONFLICT(user_id) DO UPDATE SET encrypted_secret=EXCLUDED.encrypted_secret,last_counter=-1")){upsert.setLong(1,id);upsert.setString(2,encrypted);upsert.executeUpdate();}
     try(var update=connection.prepareStatement("UPDATE users SET role='ADMIN' WHERE id=?")){update.setLong(1,id);update.executeUpdate();}
     try(var revoke=connection.prepareStatement("DELETE FROM auth_tokens WHERE user_id=?")){revoke.setLong(1,id);revoke.executeUpdate();}
     connection.commit();System.console().printf("Administrator MFA enrollment completed.%n");
   }
 }
}
