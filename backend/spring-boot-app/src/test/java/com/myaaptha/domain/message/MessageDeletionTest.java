package com.myaaptha.domain.message;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest @AutoConfigureMockMvc
class MessageDeletionTest {
  @Autowired MockMvc mvc;
  @Autowired ObjectMapper json;
  @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;
  record Member(long id,String token) {}
  Member member() throws Exception {
    String name="delete-"+UUID.randomUUID();
    var result=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username",name,"password","ExampleSecret123","phoneNumber","+1778"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();
    long id=json.readTree(result.getResponse().getContentAsString()).get("id").asLong();
    result=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",name,"password","ExampleSecret123")))).andExpect(status().isOk()).andReturn();
    return new Member(id,"Bearer "+json.readTree(result.getResponse().getContentAsString()).get("accessToken").asText());
  }
  void connect(Member a,Member b) throws Exception {mvc.perform(post("/api/network/relationships").header("Authorization",a.token()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("relatedUserId",b.id(),"type","Friend","visibilityScope","FRIENDS")))).andExpect(status().isOk());}
  @Test void removedCircleMembersCannotReadOldAttachmentsOrMutateConversation()throws Exception{
    var admin=member();var author=member();connect(admin,author);
    long circle=json.readTree(mvc.perform(post("/api/network/circles").header("Authorization",admin.token()).contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Access revocation\",\"description\":\"Synthetic security fixture\"}")).andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("id").asLong();
    mvc.perform(post("/api/network/circles/"+circle+"/members").header("Authorization",admin.token()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("userId",author.id())))).andExpect(status().isOk());
    String path="/api/network/circles/"+circle+"/posts";
    var file=new org.springframework.mock.web.MockMultipartFile("file","fixture.pdf","application/pdf",new byte[]{37,80,68,70,45,49,46,52});
    long id=json.readTree(mvc.perform(multipart(path).file(file).param("message","An authorized attachment").header("Authorization",author.token())).andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("id").asLong();
    mvc.perform(put("/api/network/circles/"+circle).header("Authorization",admin.token()).contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Access revocation\",\"description\":\"Synthetic security fixture\",\"postingPermission\":\"ADMINS_ONLY\"}")).andExpect(status().isOk());
    mvc.perform(multipart(path).param("message","Not permitted").header("Authorization",author.token())).andExpect(status().isForbidden());
    mvc.perform(get(path+"/"+id+"/attachment").header("Authorization",author.token())).andExpect(status().isOk());
    mvc.perform(delete("/api/network/circles/"+circle+"/members/"+author.id()).header("Authorization",admin.token())).andExpect(status().isOk());
    mvc.perform(get(path).header("Authorization",author.token())).andExpect(status().isForbidden());
    mvc.perform(get(path+"/search?q=authorized").header("Authorization",author.token())).andExpect(status().isForbidden());
    mvc.perform(get(path+"/"+id+"/attachment").header("Authorization",author.token())).andExpect(status().isForbidden());
    mvc.perform(put(path+"/"+id).header("Authorization",author.token()).contentType(MediaType.APPLICATION_JSON).content("{\"message\":\"Not permitted\"}")).andExpect(status().isForbidden());
    mvc.perform(delete(path+"/"+id+"/for-me").header("Authorization",author.token())).andExpect(status().isForbidden());
    mvc.perform(get(path+"/"+id+"/attachment").header("Authorization",admin.token())).andExpect(status().isOk());
  }
  @Test void concurrentDirectReadAndDeleteCannotRestoreContentOrBypassReadEligibility()throws Exception{
    var sender=member();var reader=member();connect(sender,reader);
    String out="/api/network/messages/with/"+reader.id(),in="/api/network/messages/with/"+sender.id();
    for(int run=0;run<3;run++){
      long id=send(sender,out,"Race fixture "+run);var ready=new java.util.concurrent.CountDownLatch(2);var start=new java.util.concurrent.CountDownLatch(1);
      try(var pool=java.util.concurrent.Executors.newFixedThreadPool(2)){
        var deletion=pool.submit(()->{ready.countDown();start.await();return mvc.perform(delete(out+"/"+id).header("Authorization",sender.token())).andReturn().getResponse().getStatus();});
        var read=pool.submit(()->{ready.countDown();start.await();return mvc.perform(post(in+"/read").header("Authorization",reader.token()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("messageIds",List.of(id))))).andReturn().getResponse().getStatus();});
        org.junit.jupiter.api.Assertions.assertTrue(ready.await(5,java.util.concurrent.TimeUnit.SECONDS));start.countDown();int status=deletion.get(20,java.util.concurrent.TimeUnit.SECONDS);org.junit.jupiter.api.Assertions.assertEquals(200,read.get(20,java.util.concurrent.TimeUnit.SECONDS));
        var row=jdbc.queryForMap("SELECT message,deleted_at,read_at FROM direct_messages WHERE id=?",id);
        if(status==200){org.junit.jupiter.api.Assertions.assertNotNull(row.get("deleted_at"));org.junit.jupiter.api.Assertions.assertEquals("",row.get("message"));}
        else{org.junit.jupiter.api.Assertions.assertEquals(409,status);org.junit.jupiter.api.Assertions.assertNull(row.get("deleted_at"));org.junit.jupiter.api.Assertions.assertNotNull(row.get("read_at"));}
      }
    }
  }
  long send(Member a,String path,String text) throws Exception {return json.readTree(mvc.perform(multipart(path).header("Authorization",a.token()).param("message",text)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("id").asLong();}

  @Test void directDeletionChecksOwnershipAgeReadsAndPrivateVisibility() throws Exception {
    var a=member();var b=member();var stranger=member();connect(a,b);
    String out="/api/network/messages/with/"+b.id(),in="/api/network/messages/with/"+a.id();
    long id=send(a,out,"Private removal example");
    mvc.perform(delete(out+"/"+id).header("Authorization",stranger.token())).andExpect(status().isNotFound());
    mvc.perform(delete(in+"/"+id).header("Authorization",b.token())).andExpect(status().isForbidden());
    mvc.perform(put(out+"/"+id+"/flags").header("Authorization",a.token()).contentType(MediaType.APPLICATION_JSON).content("{\"starred\":true}")).andExpect(status().isOk());
    mvc.perform(delete(out+"/"+id+"/for-me").header("Authorization",a.token())).andExpect(status().isNoContent());
    mvc.perform(get(out).header("Authorization",a.token())).andExpect(status().isOk()).andExpect(jsonPath("$[0].hiddenForMe").value(true)).andExpect(jsonPath("$[0].message").value(""));
    mvc.perform(get(in).header("Authorization",b.token())).andExpect(status().isOk()).andExpect(jsonPath("$[0].message").value("Private removal example"));
    mvc.perform(get(out+"/search?q=Private").header("Authorization",a.token())).andExpect(status().isOk()).andExpect(jsonPath("$[0]").doesNotExist());
    mvc.perform(get(out+"/saved?kind=starred").header("Authorization",a.token())).andExpect(status().isOk()).andExpect(jsonPath("$[0]").doesNotExist());
    mvc.perform(get("/api/network/messages/conversations").header("Authorization",a.token())).andExpect(status().isOk()).andExpect(jsonPath("$[0]").doesNotExist());
    long read=send(a,out,"Already read");
    mvc.perform(post(in+"/read").header("Authorization",b.token()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("messageIds",List.of(read))))).andExpect(status().isOk());
    mvc.perform(put("/api/network/messages/preferences").header("Authorization",b.token()).contentType(MediaType.APPLICATION_JSON).content("{\"readReceipts\":false}")).andExpect(status().isOk());
    mvc.perform(delete(out+"/"+read).header("Authorization",a.token())).andExpect(status().isConflict());
    long old=send(a,out,"Expired");jdbc.update("UPDATE direct_messages SET created_at=? WHERE id=?",java.sql.Timestamp.from(java.time.Instant.now().minusSeconds(86400)),old);
    mvc.perform(delete(out+"/"+old).header("Authorization",a.token())).andExpect(status().isConflict());
    mvc.perform(delete(in+"/"+old+"/for-me").header("Authorization",b.token())).andExpect(status().isNoContent());
    long fresh=send(a,out,"Fresh");mvc.perform(delete(out+"/"+fresh).header("Authorization",a.token())).andExpect(status().isOk()).andExpect(jsonPath("$.deletedAt").exists());
  }

  @Test void circleDeletionIsAdminOnlyAndPrivateDeletionPreservesOthers() throws Exception {
    var admin=member();var author=member();var reader=member();var stranger=member();connect(admin,author);connect(admin,reader);
    long circle=json.readTree(mvc.perform(post("/api/network/circles").header("Authorization",admin.token()).contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Deletion rules\",\"description\":\"Test circle\"}")).andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("id").asLong();
    for(var m:List.of(author,reader))mvc.perform(post("/api/network/circles/"+circle+"/members").header("Authorization",admin.token()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("userId",m.id())))).andExpect(status().isOk());
    String path="/api/network/circles/"+circle+"/posts";
    long fresh=send(author,path,"Admin can remove this");
    mvc.perform(delete(path+"/"+fresh).header("Authorization",author.token())).andExpect(status().isForbidden());
    mvc.perform(delete(path+"/"+fresh+"/for-me").header("Authorization",stranger.token())).andExpect(status().isForbidden());
    mvc.perform(delete(path+"/"+fresh).header("Authorization",admin.token())).andExpect(status().isOk()).andExpect(jsonPath("$.deletedAt").exists());
    long read=send(author,path,"Read by all");
    for(var m:List.of(admin,reader))mvc.perform(get(path).header("Authorization",m.token())).andExpect(status().isOk());
    mvc.perform(delete(path+"/"+read).header("Authorization",admin.token())).andExpect(status().isConflict());
    long old=send(author,path,"Old group message");jdbc.update("UPDATE circle_posts SET created_at=? WHERE id=?",java.sql.Timestamp.from(java.time.Instant.now().minusSeconds(86400)),old);
    mvc.perform(delete(path+"/"+old).header("Authorization",admin.token())).andExpect(status().isConflict());
    mvc.perform(delete(path+"/"+old+"/for-me").header("Authorization",reader.token())).andExpect(status().isNoContent());
    mvc.perform(get(path).header("Authorization",reader.token())).andExpect(status().isOk()).andExpect(jsonPath("$[?(@.id == "+old+")].hiddenForMe").value(org.hamcrest.Matchers.contains(true)));
    mvc.perform(get(path+"/search?q=Old").header("Authorization",reader.token())).andExpect(status().isOk()).andExpect(jsonPath("$[0]").doesNotExist());
    mvc.perform(get(path+"/search?q=Old").header("Authorization",author.token())).andExpect(status().isOk()).andExpect(jsonPath("$[0].message").value("Old group message"));
  }
}
