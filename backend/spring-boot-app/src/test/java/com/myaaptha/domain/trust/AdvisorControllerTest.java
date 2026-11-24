package com.myaaptha.domain.trust;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.fasterxml.jackson.databind.*;
import com.myaaptha.domain.contacts.AddressBookService;
import com.myaaptha.domain.contacts.AddressBookController.ContactInput;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
@SpringBootTest(properties={"spring.datasource.url=jdbc:h2:mem:advisors-test;MODE=PostgreSQL;DB_CLOSE_DELAY=-1"}) @AutoConfigureMockMvc
class AdvisorControllerTest {
 @Autowired MockMvc mvc;@Autowired ObjectMapper json;@Autowired JdbcTemplate db;@Autowired AddressBookService book;
 record Member(long id,String bearer){}
 String body(Object value)throws Exception{return json.writeValueAsString(value);}
 Member member()throws Exception{String name="advisor-"+UUID.randomUUID();var r=mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(body(Map.of("username",name,"password","AdvisorTest123!","phoneNumber","+1775"+String.format("%010d",Math.abs(UUID.randomUUID().getLeastSignificantBits()%10000000000L)))))).andExpect(status().isOk()).andReturn();long id=json.readTree(r.getResponse().getContentAsString()).path("id").asLong();var login=mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(body(Map.of("identifier",name,"password","AdvisorTest123!")))).andExpect(status().isOk()).andReturn();return new Member(id,"Bearer "+json.readTree(login.getResponse().getContentAsString()).path("accessToken").asText());}
 JsonNode read(Member a,String path)throws Exception{return json.readTree(mvc.perform(get(path).header("Authorization",a.bearer)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());}
 JsonNode write(Member a,String path,Object value)throws Exception{return json.readTree(mvc.perform(post(path).header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(value))).andExpect(status().isOk()).andReturn().getResponse().getContentAsString());}
 long postOf(Member a,String audience)throws Exception{return json.readTree(mvc.perform(multipart("/api/social/posts").header("Authorization",a.bearer).param("caption","Guidance for today").param("audience",audience)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).path("id").asLong();}
 @Test void privateMultiCategoryListsAllowManyPeopleAndProtectVersions()throws Exception{
  var a=member();var advisor=member();var other=member();assertEquals(12,read(a,"/api/advisors/categories").size());String custom=write(a,"/api/advisors/categories",Map.of("name","Mindfulness")).path("key").asText();assertEquals(custom,write(a,"/api/advisors/categories",Map.of("name","mindfulness")).path("key").asText());
  var first=write(a,"/api/advisors",Map.of("memberId",advisor.id,"categories",List.of("PERSONAL",custom),"notes","My private guide"));long id=first.path("id").asLong();assertTrue(first.path("followPosts").asBoolean());var merged=write(a,"/api/advisors",Map.of("memberId",advisor.id,"categories",List.of("SPORTS")));assertEquals(id,merged.path("id").asLong());assertEquals(3,merged.path("categories").size());assertTrue(merged.path("version").asLong()>first.path("version").asLong());assertEquals("My private guide",merged.path("notes").asText());
  mvc.perform(post("/api/advisors/"+id+"/update").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("categories",List.of("LAW"),"version",first.path("version").asLong())))).andExpect(status().isConflict());
  assertEquals(0,read(other,"/api/advisors").path("items").size());mvc.perform(post("/api/advisors/"+id+"/delete").header("Authorization",other.bearer)).andExpect(status().isNotFound());mvc.perform(post("/api/advisors").header("Authorization",other.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("name","Someone","categories",List.of(custom))))).andExpect(status().isBadRequest());
  for(int i=0;i<55;i++)write(a,"/api/advisors",Map.of("name","Guide "+i,"url","https://example.org/guide/"+i,"categories",List.of("ARTS")));
  var page=read(a,"/api/advisors");assertEquals(50,page.path("items").size());assertEquals(6,read(a,"/api/advisors?afterId="+page.path("nextCursor").asLong()).path("items").size());assertEquals(0,db.queryForObject("SELECT COUNT(*) FROM relationships WHERE owner_user_id=?",Integer.class,a.id));
  var updated=write(a,"/api/advisors/"+id+"/update",Map.of("categories",List.of("LAW"),"version",merged.path("version").asLong(),"followPosts",false));assertFalse(updated.path("followPosts").asBoolean());assertEquals(1,updated.path("categories").size());
 }
 @Test void contactsStayOwnerScopedAndProfileLinksAreValidated()throws Exception{
  var a=member();var other=member();book.save(a.id,List.of(new ContactInput("Coach",List.of("+18885550001"),List.of(),"Club",List.of())),"csv");long contact=book.allEntries(a.id).getFirst().id();var saved=write(a,"/api/advisors",Map.of("contactId",contact,"categories",List.of("SPORTS"),"followPosts",true));assertEquals("Coach",saved.path("name").asText());assertFalse(saved.path("followPosts").asBoolean());
  mvc.perform(post("/api/advisors").header("Authorization",other.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("contactId",contact,"categories",List.of("SPORTS"))))).andExpect(status().isNotFound());
  for(String url:List.of("javascript:alert(1)","http://example.org","https://user:password@example.org"))mvc.perform(post("/api/advisors").header("Authorization",a.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("name","Guide","url",url,"categories",List.of("PERSONAL"))))).andExpect(status().isBadRequest());
  var card=write(a,"/api/advisors",Map.of("name","External guide","url","https://example.org/profile","categories",List.of("LAW")));assertFalse(card.path("followPosts").asBoolean());assertEquals(0,read(a,"/api/advisors/feed").path("items").size());
 }
 @Test void paginatedAdvisorPostsRespectPauseSavesAndAudienceOnEveryRead()throws Exception{
  var a=member();var guide=member();var other=member();var advisor=write(a,"/api/advisors",Map.of("memberId",guide.id,"categories",List.of("EDUCATION_CAREER")));long hidden=postOf(guide,"PRIVATE");for(int i=0;i<25;i++)db.update("INSERT INTO social_posts(author_user_id,caption,audience) VALUES(?, ?, 'PUBLIC')",guide.id,"Guidance "+i);postOf(other,"PUBLIC");var first=read(a,"/api/advisors/feed");assertEquals(20,first.path("items").size());String cursor=first.path("nextCursor").asText();var second=read(a,"/api/advisors/feed?before="+cursor);assertEquals(5,second.path("items").size());Set<Long> ids=new HashSet<>();for(var p:first.path("items")){assertEquals(guide.id,p.path("authorUserId").asLong());ids.add(p.path("id").asLong());}for(var p:second.path("items"))assertTrue(ids.add(p.path("id").asLong()));assertFalse(ids.contains(hidden));assertEquals(0,read(a,"/api/advisors/feed?category=SPORTS").path("items").size());
  long visible=first.path("items").get(0).path("id").asLong();write(a,"/api/social/posts/"+visible+"/save",Map.of());assertEquals(1,read(a,"/api/advisors/feed?saved=true").path("items").size());db.update("UPDATE social_posts SET audience='PRIVATE' WHERE id=?",visible);assertEquals(0,read(a,"/api/advisors/feed?saved=true").path("items").size());
  write(a,"/api/advisors/"+advisor.path("id").asLong()+"/update",Map.of("version",advisor.path("version").asLong(),"categories",List.of("EDUCATION_CAREER"),"followPosts",false));assertEquals(0,read(a,"/api/advisors/feed").path("items").size());
 }
 @Test void repostsAreIdempotentRevocableAndNeverExposePrivateOriginals()throws Exception{
  var a=member();var guide=member();var original=member();long post=postOf(original,"PUBLIC");write(a,"/api/advisors",Map.of("memberId",guide.id,"categories",List.of("PERSONAL")));
  write(guide,"/api/social/posts/"+post+"/repost",Map.of("reposted",true));write(guide,"/api/social/posts/"+post+"/repost",Map.of("reposted",true));assertEquals(1,db.queryForObject("SELECT COUNT(*) FROM social_reposts WHERE post_id=?",Integer.class,post));var item=read(a,"/api/advisors/feed").path("items").get(0);assertEquals(guide.id,item.path("repostedByUserId").asLong());assertEquals(original.id,item.path("authorUserId").asLong());
  db.update("UPDATE social_posts SET audience='PRIVATE' WHERE id=?",post);assertEquals(0,read(a,"/api/advisors/feed").path("items").size());mvc.perform(post("/api/social/posts/"+post+"/repost").header("Authorization",original.bearer).contentType(MediaType.APPLICATION_JSON).content(body(Map.of("reposted",true)))).andExpect(status().isBadRequest());
  db.update("UPDATE social_posts SET audience='PUBLIC' WHERE id=?",post);write(guide,"/api/social/posts/"+post+"/repost",Map.of("reposted",false));assertEquals(0,read(a,"/api/advisors/feed").path("items").size());
 }
}
