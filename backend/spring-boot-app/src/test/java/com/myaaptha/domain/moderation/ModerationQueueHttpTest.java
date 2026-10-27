package com.myaaptha.domain.moderation;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.myaaptha.config.ApiExceptionHandler;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import com.myaaptha.domain.social.SocialPostRepository;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class ModerationQueueHttpTest {
 @Test void queryParametersAndPageShapeMatchBothClientContracts()throws Exception{
  var reports=mock(AbuseReportRepository.class);var users=mock(UserRepository.class);var admin=new UserEntity();admin.setRole("ADMIN");when(users.findById(8L)).thenReturn(Optional.of(admin));
  var rows=new ArrayList<AbuseReportEntity>();for(long id:List.of(9L,8L,7L)){var r=mock(AbuseReportEntity.class);when(r.getId()).thenReturn(id);when(r.getStatus()).thenReturn("OPEN");rows.add(r);}
  when(reports.findByStatusAndIdLessThanOrderByIdDesc(eq("OPEN"),eq(10L),any())).thenReturn(rows);
  var mvc=MockMvcBuilders.standaloneSetup(new ModerationController(reports,users,mock(SocialPostRepository.class))).setControllerAdvice(new ApiExceptionHandler()).build();
  mvc.perform(get("/api/moderation/reports/queue").principal(()->"8").param("status","OPEN").param("beforeId","10").param("limit","2"))
   .andExpect(status().isOk()).andExpect(jsonPath("$.items.length()").value(2)).andExpect(jsonPath("$.items[0].id").value(9)).andExpect(jsonPath("$.nextCursor").value(8));
  mvc.perform(get("/api/moderation/reports/queue").principal(()->"8").param("limit","101")).andExpect(status().isBadRequest());
 }
 @Test void unknownMemberCannotReadQueueMetadata()throws Exception{
  var reports=mock(AbuseReportRepository.class);var users=mock(UserRepository.class);var member=new UserEntity();member.setRole("USER");when(users.findById(8L)).thenReturn(Optional.of(member));
  var mvc=MockMvcBuilders.standaloneSetup(new ModerationController(reports,users,mock(SocialPostRepository.class))).setControllerAdvice(new ApiExceptionHandler()).build();
  mvc.perform(get("/api/moderation/reports/queue").principal(()->"8")).andExpect(status().isForbidden());verifyNoInteractions(reports);
 }
}
