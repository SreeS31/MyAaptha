const workspacePrimaryLabels = <String>['Feed','My posts','Followers','Following','Discover','Messages','My circles','My contacts','Find people & circles','Dashboard','Life timeline','My profile','Trust center','Relationships','Diary & Memories','Health','Finance','Career','Advisors & well-wishers','Interests','Notifications','Account & tools','Ask MyAaptha'];
const workspacePrimaryIndexes = <int>[13,17,18,19,5,2,3,16,21,0,14,6,15,8,1,9,10,11,22,12,4,7,20];
const workspaceMenuMoves = <({String old, String destination, String path})>[
  (old: "Dashboard", destination: "Dashboard > Overview", path: "/dashboard"),
  (old: "Relationship tree", destination: "Relationships", path: "/relationship-tree"),
  (old: "Diary & memories", destination: "Diary & Memories", path: "/feed"),
  (old: "Following & followers", destination: "Community > Following", path: "/following"),
  (old: "Messages", destination: "Messages > Personal & groups", path: "/messages"),
  (old: "My circles", destination: "Messages > My circles", path: "/circles"),
  (old: "My contacts", destination: "Messages > My contacts", path: "/contacts"),
  (old: "Life timeline", destination: "Dashboard > Life timeline", path: "/timeline"),
  (old: "Money & insights", destination: "Finance", path: "/finance"),
  (old: "Health records", destination: "Health", path: "/health"),
  (old: "Trust center", destination: "Dashboard > Trust center", path: "/trust"),
  (old: "My profile", destination: "Dashboard > My profile", path: "/profile"),
  (old: "Settings", destination: "Account & tools > Settings", path: "/settings"),
  (old: "Account sessions", destination: "Account & tools > Account sessions", path: "/session"),
  (old: "AI controls", destination: "Account & tools > AI controls", path: "/ai-activity"),
  (old: "Ask MyAaptha", destination: "Account & tools > Ask MyAaptha", path: "/help"),
  (old: "My reports", destination: "Account & tools > My reports", path: "/reports"),
  (old: "Moderation", destination: "Account & tools > Moderation", path: "/moderation"),
  (old: "Security & errors (administrators)", destination: "Administration > Security & errors", path: "/security-reports"),
];
