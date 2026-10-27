package com.myaaptha.domain.message;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest @AutoConfigureMockMvc
class MessageFeaturesTest {
  @Autowired MockMvc mvc;
  @Autowired ObjectMapper json;
  record Member(long id,String bearer) {}
  Member member() throws Exception {
    String name="message-"+UUID.randomUUID();
    var created=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("username",name,"password","ExampleSecret123","phoneNumber","+1777"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();
    long id=json.readTree(created.getResponse().getContentAsString()).get("id").asLong();
    var auth=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("identifier",name,"password","ExampleSecret123")))).andExpect(status().isOk()).andReturn();
    return new Member(id,"Bearer "+json.readTree(auth.getResponse().getContentAsString()).get("accessToken").asText());
  }
  @Test void privateFlagsPinsAndExplicitReceiptsSyncAndRespectOwnership() throws Exception {
    var sender=member();var recipient=member();var stranger=member();
    mvc.perform(post("/api/network/relationships").header("Authorization",sender.bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("relatedUserId",recipient.id(),"type","Friend","visibilityScope","FRIENDS")))).andExpect(status().isOk());
    var sent=mvc.perform(multipart("/api/network/messages/with/"+recipient.id()).header("Authorization",sender.bearer()).param("message","Saved message example")).andExpect(status().isOk()).andExpect(jsonPath("$.deliveredAt").doesNotExist()).andExpect(jsonPath("$.readAt").doesNotExist()).andReturn();
    long id=json.readTree(sent.getResponse().getContentAsString()).get("id").asLong();
    String fromSender="/api/network/messages/with/"+recipient.id(),fromRecipient="/api/network/messages/with/"+sender.id();
    mvc.perform(put(fromSender+"/"+id+"/flags").header("Authorization",sender.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"starred\":true,\"pinned\":true}"))
        .andExpect(status().isOk()).andExpect(jsonPath("$.starred").value(true)).andExpect(jsonPath("$.pinned").value(true));
    mvc.perform(get(fromSender+"/saved?kind=starred").header("Authorization",sender.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].id").value(id));
    mvc.perform(get(fromRecipient+"/saved?kind=starred").header("Authorization",recipient.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0]").doesNotExist());
    mvc.perform(put(fromSender+"/"+id+"/flags").header("Authorization",stranger.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"starred\":true}"))
        .andExpect(status().isNotFound());
    mvc.perform(get(fromSender+"/saved?kind=invalid").header("Authorization",sender.bearer())).andExpect(status().isBadRequest());
    mvc.perform(get(fromRecipient).header("Authorization",recipient.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].deliveredAt").exists()).andExpect(jsonPath("$[0].readAt").doesNotExist()).andExpect(jsonPath("$[0].starred").value(false));
    String receipt=json.writeValueAsString(Map.of("messageIds",List.of(id)));
    mvc.perform(post(fromSender+"/read").header("Authorization",sender.bearer()).contentType(MediaType.APPLICATION_JSON).content(receipt)).andExpect(status().isNotFound());
    mvc.perform(post(fromRecipient+"/read").header("Authorization",recipient.bearer()).contentType(MediaType.APPLICATION_JSON).content(receipt)).andExpect(status().isOk());
    mvc.perform(get(fromSender).header("Authorization",sender.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].readAt").exists());
    mvc.perform(put("/api/network/messages/preferences").header("Authorization",recipient.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"readReceipts\":false}")).andExpect(status().isOk());
    mvc.perform(get(fromSender).header("Authorization",sender.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].readAt").doesNotExist());
    mvc.perform(get("/api/network/messages/conversations").header("Authorization",recipient.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].unreadCount").value(0));
    mvc.perform(put(fromSender+"/pin").header("Authorization",sender.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"pinned\":true}")).andExpect(status().isOk());
    mvc.perform(get("/api/network/messages/conversations").header("Authorization",sender.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].pinned").value(true));
    mvc.perform(get("/api/network/messages/conversations").header("Authorization",recipient.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].pinned").value(false));
    mvc.perform(put(fromSender+"/"+id+"/flags").header("Authorization",sender.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"starred\":false}")).andExpect(status().isOk()).andExpect(jsonPath("$.pinned").value(true));
    mvc.perform(get(fromSender+"/saved?kind=starred").header("Authorization",sender.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0]").doesNotExist());
    mvc.perform(delete(fromSender+"/"+id).header("Authorization",sender.bearer())).andExpect(status().isConflict());
    mvc.perform(delete(fromSender+"/"+id+"/for-me").header("Authorization",sender.bearer())).andExpect(status().isNoContent());
    mvc.perform(get(fromSender+"/saved?kind=pinned").header("Authorization",sender.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0]").doesNotExist());
    mvc.perform(put(fromSender+"/"+id+"/flags").header("Authorization",sender.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"starred\":true}")).andExpect(status().isNotFound());
    mvc.perform(post(fromRecipient+"/read").header("Authorization",recipient.bearer()).contentType(MediaType.APPLICATION_JSON).content("{\"messageIds\":[]}")).andExpect(status().isBadRequest());
  }
  @Autowired com.myaaptha.domain.notification.NotificationRepository notifications;
  @Autowired com.myaaptha.domain.notification.NotificationService notificationService;
  @Test void archiveMuteAndUnreadArePrivateAndDoNotUndoReceipts() throws Exception {
    var sender=member();var recipient=member();var stranger=member();
    mvc.perform(post("/api/network/relationships").header("Authorization",sender.bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("relatedUserId",recipient.id(),"type","Friend","visibilityScope","FRIENDS")))).andExpect(status().isOk());
    String outgoing="/api/network/messages/with/"+recipient.id(), incoming="/api/network/messages/with/"+sender.id();
    var sent=mvc.perform(multipart(outgoing).header("Authorization",sender.bearer()).param("message","First message")).andExpect(status().isOk()).andReturn();
    long id=json.readTree(sent.getResponse().getContentAsString()).get("id").asLong();
    mvc.perform(post(incoming+"/read").header("Authorization",recipient.bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("messageIds",List.of(id))))).andExpect(status().isOk());
    var firstAlert=notifications.findTop100ByUserIdOrderByCreatedAtDesc(recipient.id()).stream().filter(n->"DIRECT_MESSAGE".equals(n.getType())).findFirst().orElseThrow();
    mvc.perform(put(incoming+"/settings").header("Authorization",recipient.bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("archived",true,"muted",true,"markedUnread",true)))).andExpect(status().isOk());
    org.junit.jupiter.api.Assertions.assertFalse(notificationService.deliveryEnabled(firstAlert,"PUSH"));
    mvc.perform(get("/api/network/messages/conversations").header("Authorization",recipient.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].archived").value(true)).andExpect(jsonPath("$[0].muted").value(true)).andExpect(jsonPath("$[0].markedUnread").value(true)).andExpect(jsonPath("$[0].unreadCount").value(0));
    mvc.perform(get("/api/network/messages/conversations").header("Authorization",sender.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].archived").value(false)).andExpect(jsonPath("$[0].muted").value(false)).andExpect(jsonPath("$[0].markedUnread").value(false));
    mvc.perform(get(outgoing).header("Authorization",sender.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].readAt").exists());
    long before=notifications.countByUserIdAndReadAtIsNull(recipient.id());
    mvc.perform(multipart(outgoing).header("Authorization",sender.bearer()).param("message","Muted but retained")).andExpect(status().isOk());
    org.junit.jupiter.api.Assertions.assertEquals(before,notifications.countByUserIdAndReadAtIsNull(recipient.id()));
    mvc.perform(get(incoming).header("Authorization",recipient.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[1].message").value("Muted but retained"));
    mvc.perform(put(incoming+"/settings").header("Authorization",recipient.bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("markedUnread",false)))).andExpect(status().isOk());
    mvc.perform(get("/api/network/messages/conversations").header("Authorization",recipient.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].archived").value(true)).andExpect(jsonPath("$[0].muted").value(true)).andExpect(jsonPath("$[0].markedUnread").value(false)).andExpect(jsonPath("$[0].unreadCount").value(1));
    mvc.perform(put(incoming+"/settings").header("Authorization",recipient.bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("muted",false,"archived",false)))).andExpect(status().isOk());
    mvc.perform(multipart(outgoing).header("Authorization",sender.bearer()).param("message","Alerts resumed")).andExpect(status().isOk());
    org.junit.jupiter.api.Assertions.assertEquals(before+1,notifications.countByUserIdAndReadAtIsNull(recipient.id()));
    mvc.perform(put(incoming+"/settings").header("Authorization",stranger.bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("muted",true)))).andExpect(status().isNotFound());
    mvc.perform(put(incoming+"/settings").header("Authorization",recipient.bearer()).contentType(MediaType.APPLICATION_JSON).content("{}")).andExpect(status().isBadRequest());
    mvc.perform(put(incoming+"/settings").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("muted",true)))).andExpect(status().isUnauthorized());
  }

  @Test void forwardingCopiesAttachmentsAndEnforcesConversationAccess() throws Exception {
    var author=member();var forwarder=member();var target=member();var stranger=member();
    for(var pair:List.of(List.of(author,forwarder),List.of(forwarder,target))) {
      mvc.perform(post("/api/network/relationships").header("Authorization",pair.get(0).bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("relatedUserId",pair.get(1).id(),"type","Friend","visibilityScope","FRIENDS")))).andExpect(status().isOk());
    }
    byte[] content="Test attachment for independent forwarding".getBytes(java.nio.charset.StandardCharsets.UTF_8);
    var sent=mvc.perform(multipart("/api/network/messages/with/"+forwarder.id()).file(new org.springframework.mock.web.MockMultipartFile("file","notes.txt","text/plain",content)).header("Authorization",author.bearer()).param("message","Forward this attachment")).andExpect(status().isOk()).andReturn();
    long source=json.readTree(sent.getResponse().getContentAsString()).get("id").asLong();
    String path="/api/network/messages/with/"+author.id()+"/"+source+"/forward";
    String payload=json.writeValueAsString(Map.of("recipientId",target.id()));
    mvc.perform(post(path).header("Authorization",stranger.bearer()).contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isNotFound());
    mvc.perform(post(path).header("Authorization",forwarder.bearer()).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("recipientId",stranger.id())))).andExpect(status().isForbidden());
    var copied=mvc.perform(post(path).header("Authorization",forwarder.bearer()).contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isOk()).andExpect(jsonPath("$.forwarded").value(true)).andExpect(jsonPath("$.senderId").value(forwarder.id())).andExpect(jsonPath("$.recipientId").value(target.id())).andExpect(jsonPath("$.replyToMessageId").doesNotExist()).andExpect(jsonPath("$.starred").value(false)).andExpect(jsonPath("$.attachmentName").value("notes.txt")).andReturn();
    long copy=json.readTree(copied.getResponse().getContentAsString()).get("id").asLong();
    mvc.perform(delete("/api/network/messages/with/"+forwarder.id()+"/"+source).header("Authorization",author.bearer())).andExpect(status().isOk());
    mvc.perform(get("/api/network/messages/with/"+forwarder.id()+"/"+copy+"/attachment").header("Authorization",target.bearer())).andExpect(status().isOk()).andExpect(content().bytes(content));
    mvc.perform(post(path).header("Authorization",forwarder.bearer()).contentType(MediaType.APPLICATION_JSON).content(payload)).andExpect(status().isBadRequest());
    mvc.perform(get("/api/network/messages/with/"+forwarder.id()).header("Authorization",target.bearer())).andExpect(status().isOk()).andExpect(jsonPath("$[0].forwarded").value(true));
  }

}
