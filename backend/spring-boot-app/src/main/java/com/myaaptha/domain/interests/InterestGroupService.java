package com.myaaptha.domain.interests;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import com.myaaptha.domain.profile.UserProfileRepository;
import com.myaaptha.domain.profile.model.UserProfileEntity;

@Service
@Transactional
public class InterestGroupService {
    public record GroupInput(String name, String topic, String area, String description) {}
    public record Group(String id, String name, String topic, String area, String description,
                        boolean admin, String membership, long memberCount) {}
    public record Member(long userId, String name) {}
    public record Discussion(String id, String author, String body, String createdAt, boolean mine) {}
    public record Page<T>(List<T> items, boolean hasNext) {}
    private final JdbcTemplate db;
    private final UserProfileRepository profiles;
    public InterestGroupService(JdbcTemplate db, UserProfileRepository profiles) { this.db=db; this.profiles=profiles; }

    @Transactional(readOnly=true)
    public List<String> interests(long user) {
        return profiles.findById(user).map(p -> p.getHobbies()==null ? List.<String>of() :
            Arrays.stream(p.getHobbies().split(",")).map(String::trim).filter(s->!s.isEmpty()).distinct().toList()).orElse(List.of());
    }
    public List<String> saveInterests(long user, List<String> values) {
        if(values==null) throw error(HttpStatus.BAD_REQUEST,"Choose interests to save");
        Map<String,String> unique=new LinkedHashMap<>();
        for(String value:values) {
            String clean=text(value,120,"Interest");
            if(clean.contains(",")) throw error(HttpStatus.BAD_REQUEST,"Use separate selections for each interest");
            unique.putIfAbsent(clean.toLowerCase(Locale.ROOT),clean);
        }
        // Only update hobbies; never overwrite profile/career fields from a stale browser form.
        var profile=profiles.findById(user).orElseGet(()->{var p=new UserProfileEntity();p.setUserId(user);return p;});
        profile.setHobbies(String.join(", ",unique.values())); profiles.save(profile);
        return List.copyOf(unique.values());
    }
    @Transactional(readOnly=true)
    public Page<Group> directory(long user, String query, String area, String topic, boolean mine, int page) {
        checkPage(page);
        String sql="SELECT g.*, m.status AS membership, (SELECT COUNT(*) FROM interest_group_members c WHERE c.group_id=g.id AND c.status='ACTIVE') AS member_count FROM interest_groups g LEFT JOIN interest_group_members m ON m.group_id=g.id AND m.user_id=? WHERE 1=1";
        List<Object> args=new ArrayList<>(); args.add(user);
        if(query!=null&&!query.isBlank()) {String pattern=pattern(query);sql+=" AND (LOWER(g.name) LIKE ? ESCAPE '!' OR LOWER(g.topic) LIKE ? ESCAPE '!' OR LOWER(g.description) LIKE ? ESCAPE '!')";args.add(pattern);args.add(pattern);args.add(pattern);}
        if(area!=null&&!area.isBlank()){sql+=" AND LOWER(g.area) LIKE ? ESCAPE '!'";args.add(pattern(area));}
        if(topic!=null&&!topic.isBlank()){sql+=" AND LOWER(g.topic)=?";args.add(topic.trim().toLowerCase(Locale.ROOT));}
        if(mine) sql+=" AND (g.owner_user_id="+user+" OR m.status IN ('ACTIVE','REQUESTED'))";
        sql+=" ORDER BY g.created_at DESC,g.id DESC LIMIT 25 OFFSET ?";args.add(page*24L);
        List<Group> items=db.query(sql,(r,n)->group(r,user),args.toArray());
        return new Page<>(items.stream().limit(24).toList(),items.size()>24);
    }
    public Group create(long user, GroupInput input) {
        validate(input);String id=UUID.randomUUID().toString();
        db.update("INSERT INTO interest_groups(id,owner_user_id,name,topic,area,description) VALUES (?,?,?,?,?,?)",id,user,input.name().trim(),input.topic().trim(),input.area().trim(),input.description().trim());
        db.update("INSERT INTO interest_group_members(group_id,user_id,status) VALUES (?,?,'ACTIVE')",id,user);
        return detail(user,id);
    }
    public Group edit(long user,String id,GroupInput input) {
        validate(input);lock(id);admin(user,id);
        db.update("UPDATE interest_groups SET name=?,topic=?,area=?,description=? WHERE id=?",input.name().trim(),input.topic().trim(),input.area().trim(),input.description().trim(),id);
        return detail(user,id);
    }
    @Transactional(readOnly=true)
    public Group detail(long user,String id) {
        var list=db.query("SELECT g.*,m.status AS membership,(SELECT COUNT(*) FROM interest_group_members c WHERE c.group_id=g.id AND c.status='ACTIVE') AS member_count FROM interest_groups g LEFT JOIN interest_group_members m ON m.group_id=g.id AND m.user_id=? WHERE g.id=?",(r,n)->group(r,user),user,id);
        if(list.isEmpty())throw error(HttpStatus.NOT_FOUND,"Group not found");return list.get(0);
    }
    public Group request(long user,String id) {
        lock(id);String current=status(user,id);
        if(!"ACTIVE".equals(current)&&!"REQUESTED".equals(current)) {
            if(current==null)db.update("INSERT INTO interest_group_members(group_id,user_id,status) VALUES (?,?,'REQUESTED')",id,user);
            else db.update("UPDATE interest_group_members SET status='REQUESTED',requested_at=CURRENT_TIMESTAMP WHERE group_id=? AND user_id=?",id,user);
        }
        return detail(user,id);
    }
    public Group leave(long user,String id) {
        lock(id);if(detail(user,id).admin())throw error(HttpStatus.BAD_REQUEST,"The group creator must remain its admin");
        db.update("UPDATE interest_group_members SET status='LEFT' WHERE group_id=? AND user_id=?",id,user);return detail(user,id);
    }
    @Transactional(readOnly=true)
    public Page<Member> requests(long user,String id,int page) {
        checkPage(page);admin(user,id);
        var result=db.query("SELECT u.id,u.username FROM interest_group_members m JOIN users u ON u.id=m.user_id WHERE m.group_id=? AND m.status='REQUESTED' ORDER BY m.requested_at,u.id LIMIT 25 OFFSET ?",(r,n)->new Member(r.getLong(1),r.getString(2)),id,page*24L);
        return new Page<>(result.stream().limit(24).toList(),result.size()>24);
    }
    public void decide(long user,String id,long member,boolean approve) {
        lock(id);admin(user,id);
        if(db.update("UPDATE interest_group_members SET status=? WHERE group_id=? AND user_id=? AND status='REQUESTED'",approve?"ACTIVE":"REJECTED",id,member)!=1)
            throw error(HttpStatus.CONFLICT,"This request has already changed. Refresh the request list.");
    }
    @Transactional(readOnly=true)
    public Page<Discussion> messages(long user,String id,int page) {
        checkPage(page);active(user,id);
        var result=db.query("SELECT m.*,u.username FROM interest_group_messages m JOIN users u ON u.id=m.author_user_id WHERE m.group_id=? ORDER BY m.created_at DESC,m.id DESC LIMIT 31 OFFSET ?",(r,n)->new Discussion(r.getString("id"),r.getString("username"),r.getString("body"),r.getTimestamp("created_at").toInstant().toString(),r.getLong("author_user_id")==user),id,page*30L);
        return new Page<>(result.stream().limit(30).toList(),result.size()>30);
    }
    public void post(long user,String id,String body) {
        String clean=text(body,10000,"Message");lock(id);active(user,id);
        db.update("INSERT INTO interest_group_messages(id,group_id,author_user_id,body) VALUES (?,?,?,?)",UUID.randomUUID().toString(),id,user,clean);
    }
    public void deleteMessage(long user,String id,String message) {
        lock(id);active(user,id);boolean admin=detail(user,id).admin();
        int changed=db.update("DELETE FROM interest_group_messages WHERE id=? AND group_id=? AND (author_user_id=? OR ?=TRUE)",message,id,user,admin);
        if(changed==0)throw error(HttpStatus.NOT_FOUND,"Message not found or not yours");
    }
    private void active(long user,String id){detail(user,id);if(!"ACTIVE".equals(status(user,id)))throw error(HttpStatus.FORBIDDEN,"Join this group and wait for admin approval to read or post discussions");}
    private void admin(long user,String id){if(!detail(user,id).admin())throw error(HttpStatus.FORBIDDEN,"Only the group admin can manage requests");}
    private String status(long user,String id){var rows=db.queryForList("SELECT status FROM interest_group_members WHERE group_id=? AND user_id=?",String.class,id,user);return rows.isEmpty()?null:rows.get(0);}
    private void lock(String id){if(db.queryForList("SELECT id FROM interest_groups WHERE id=? FOR UPDATE",String.class,id).isEmpty())throw error(HttpStatus.NOT_FOUND,"Group not found");}
    private Group group(ResultSet r,long user)throws SQLException{return new Group(r.getString("id"),r.getString("name"),r.getString("topic"),r.getString("area"),r.getString("description"),r.getLong("owner_user_id")==user,r.getString("membership"),r.getLong("member_count"));}
    private void validate(GroupInput input){if(input==null)throw error(HttpStatus.BAD_REQUEST,"Group details are required");text(input.name(),160,"Group name");text(input.topic(),120,"Interest");text(input.area(),200,"Area");text(input.description(),4000,"Description");}
    private String text(String value,int max,String label){if(value==null||value.isBlank()||value.trim().length()>max)throw error(HttpStatus.BAD_REQUEST,label+" is required and must be at most "+max+" characters");return value.trim();}
    private String pattern(String value){if(value.length()>200)throw error(HttpStatus.BAD_REQUEST,"Search must be at most 200 characters");return "%"+value.trim().toLowerCase(Locale.ROOT).replace("!","!!").replace("%","!%").replace("_","!_")+"%";}
    private void checkPage(int page){if(page<0)throw error(HttpStatus.BAD_REQUEST,"Page must be zero or greater");}
    private ResponseStatusException error(HttpStatus code,String message){return new ResponseStatusException(code,message);}
}
