package db.migration.common;

import java.util.ArrayList;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

/** Earlier schema made circle names globally unique, preventing two owners from having Family. */
public class V60__scope_circle_names_to_owner extends BaseJavaMigration {
  @Override public void migrate(Context context)throws Exception {
    var names=new ArrayList<String>();
    try(var statement=context.getConnection().createStatement();var rows=statement.executeQuery("SELECT tc.constraint_name FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage k ON tc.constraint_name=k.constraint_name AND tc.constraint_schema=k.constraint_schema WHERE LOWER(tc.table_name)='circles' AND tc.constraint_type='UNIQUE' GROUP BY tc.constraint_name HAVING COUNT(*)=1 AND MIN(LOWER(k.column_name))='name'")){
      while(rows.next())names.add(rows.getString(1));
    }
    try(var statement=context.getConnection().createStatement()){
      for(String name:names)statement.execute("ALTER TABLE circles DROP CONSTRAINT \""+name.replace("\"","\"\"")+"\"");
      statement.execute("CREATE UNIQUE INDEX uq_circles_owner_name ON circles(owner_user_id,name)");
    }
  }
}
