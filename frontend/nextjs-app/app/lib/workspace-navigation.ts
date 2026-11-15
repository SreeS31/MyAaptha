export type WorkspaceSection = {label:string;href:string;icon:string;tabs:{label:string;href:string}[]};
export const primaryNavigation:WorkspaceSection[] = [
  {
    "label": "Feed",
    "href": "/online-feed",
    "icon": "",
    "tabs": [
      {
        "label": "Feed",
        "href": "/online-feed"
      }
    ]
  },
  {
    "label": "My posts",
    "href": "/posts",
    "icon": "",
    "tabs": [
      {
        "label": "My posts",
        "href": "/posts"
      }
    ]
  },
  {
    "label": "Followers",
    "href": "/followers",
    "icon": "",
    "tabs": [
      {
        "label": "Followers",
        "href": "/followers"
      }
    ]
  },
  {
    "label": "Following",
    "href": "/following",
    "icon": "",
    "tabs": [
      {
        "label": "Following",
        "href": "/following"
      }
    ]
  },
  {
    "label": "Discover",
    "href": "/discover",
    "icon": "",
    "tabs": [
      {
        "label": "Discover",
        "href": "/discover"
      }
    ]
  },
  {
    "label": "Messages",
    "href": "/messages",
    "icon": "\u2709",
    "tabs": [
      {
        "label": "Personal & groups",
        "href": "/messages"
      },
      {
        "label": "My circles",
        "href": "/circles"
      },
      {
        "label": "My contacts",
        "href": "/contacts"
      },
      {
        "label": "Find people & circles",
        "href": "/circle-search"
      }
    ]
  },
  {
    "label": "Dashboard",
    "href": "/dashboard",
    "icon": "\u2302",
    "tabs": [
      {
        "label": "Overview",
        "href": "/dashboard"
      },
      {
        "label": "Life timeline",
        "href": "/timeline"
      },
      {
        "label": "My profile",
        "href": "/profile"
      },
      {
        "label": "Trust center",
        "href": "/trust"
      }
    ]
  },
  {
    "label": "Relationships",
    "href": "/relationship-tree",
    "icon": "\u2667",
    "tabs": [
      {
        "label": "Relationship tree",
        "href": "/relationship-tree"
      }
    ]
  },
  {
    "label": "Diary & Memories",
    "href": "/feed",
    "icon": "\u270e",
    "tabs": [
      {
        "label": "Diary & memories",
        "href": "/feed"
      }
    ]
  },
  {
    "label": "Health",
    "href": "/health",
    "icon": "\u2661",
    "tabs": [
      {
        "label": "Health records",
        "href": "/health"
      }
    ]
  },
  {
    "label": "Finance",
    "href": "/finance",
    "icon": "\u20b9",
    "tabs": [
      {
        "label": "Money & renewals",
        "href": "/finance"
      }
    ]
  },
  {
    "label": "Career",
    "href": "/career",
    "icon": "\u25a3",
    "tabs": [
      {
        "label": "Career",
        "href": "/career"
      }
    ]
  },
  {
    "label": "Interests",
    "href": "/interests",
    "icon": "\u2727",
    "tabs": [
      {
        "label": "Interests",
        "href": "/interests"
      }
    ]
  }
];
export const menuMoves = [
  {
    "old": "Dashboard",
    "href": "/dashboard",
    "destination": "Dashboard > Overview"
  },
  {
    "old": "Relationship tree",
    "href": "/relationship-tree",
    "destination": "Relationships"
  },
  {
    "old": "Diary & memories",
    "href": "/feed",
    "destination": "Diary & Memories"
  },
  {
    "old": "Following & followers",
    "href": "/following",
    "destination": "Community > Following"
  },
  {
    "old": "Messages",
    "href": "/messages",
    "destination": "Messages > Personal & groups"
  },
  {
    "old": "My circles",
    "href": "/circles",
    "destination": "Messages > My circles"
  },
  {
    "old": "My contacts",
    "href": "/contacts",
    "destination": "Messages > My contacts"
  },
  {
    "old": "Life timeline",
    "href": "/timeline",
    "destination": "Dashboard > Life timeline"
  },
  {
    "old": "Money & insights",
    "href": "/finance",
    "destination": "Finance"
  },
  {
    "old": "Health records",
    "href": "/health",
    "destination": "Health"
  },
  {
    "old": "Trust center",
    "href": "/trust",
    "destination": "Dashboard > Trust center"
  },
  {
    "old": "My profile",
    "href": "/profile",
    "destination": "Dashboard > My profile"
  },
  {
    "old": "Settings",
    "href": "/settings",
    "destination": "Account & tools > Settings"
  },
  {
    "old": "Account sessions",
    "href": "/session",
    "destination": "Account & tools > Account sessions"
  },
  {
    "old": "AI controls",
    "href": "/ai-activity",
    "destination": "Account & tools > AI controls"
  },
  {
    "old": "Ask MyAaptha",
    "href": "/help",
    "destination": "Account & tools > Ask MyAaptha"
  },
  {
    "old": "My reports",
    "href": "/reports",
    "destination": "Account & tools > My reports"
  },
  {
    "old": "Moderation",
    "href": "/moderation",
    "destination": "Account & tools > Moderation"
  },
  {
    "old": "Security & errors (administrators)",
    "href": "/security-reports",
    "destination": "Administration > Security & errors"
  }
];
export function sectionForPath(path:string){return primaryNavigation.find(section=>section.tabs.some(tab=>path===tab.href||path.startsWith(tab.href+"/")));}
