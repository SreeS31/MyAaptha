# MyAaptha UI/UX Design Specification

## Design System

### Visual Language
- **Style:** Glassmorphism + Material Design 3
- **Typography:** Inter (web), Roboto (mobile)
- **Primary:** Purple `#7C3AED`
- **Radius:** 12–16px cards, 8px inputs
- **Elevation:** Soft shadows, backdrop blur on cards

### Color Standards (Nodes)

| Context | Color / Border |
|---------|----------------|
| Male | Light blue `#93C5FD` |
| Female | Light pink `#FBCFE8` |
| Unknown | Light gray `#D1D5DB` |
| Current user | Green border `#22C55E` |
| Owner | Gold border `#EAB308` |
| Editor | Orange border `#F97316` |
| Viewer | Gray border `#9CA3AF` |
| Selected | Purple border `#7C3AED` |

### Themes
- Light and dark mode via `next-themes` (web) and `ThemeMode.system` (Flutter)
- WCAG 2.1 AA contrast for text

## Screen Inventory (Figma-ready)

### Authentication
1. **Landing** — hero, feature grid, CTA
2. **Login** — email/mobile, OAuth buttons, forgot password
3. **Register** — step form with OTP verification
4. **2FA** — TOTP / SMS code entry
5. **Device trust** — remember this device checkbox

### Dashboard
6. **Overview** — stat cards, circle grid, activity timeline
7. **Notifications panel** — slide-over drawer
8. **Global search** — command palette (⌘K)

### Circle Management
9. **Circle list** — filter by category, sort, archive toggle
10. **Create circle** — wizard: name → category → visibility → template
11. **Circle settings** — ACL, sharing, export, version history

### Tree Visualization
12. **Tree canvas** — React Flow full viewport, minimap, toolbar
13. **Node detail drawer** — profile tabs: Info, Contacts, Media, Documents
14. **Add node modal** — quick add vs full profile
15. **Relationship picker** — searchable type list + custom

### Communication
16. **Compose message** — channel selector, audience filters
17. **Filter builder** — visual query builder for tree segments

### Calendar
18. **Month view** — birthdays, events, festivals
19. **Event detail** — RSVP, attendees, reminders

### Reports
20. **Report builder** — template selection, preview, export

### Mobile-specific
21. **Biometric gate**
22. **QR scanner**
23. **Offline sync status bar**

## Wireframe Descriptions

### Landing (Desktop 1440px)
```
┌─────────────────────────────────────────────────────────────┐
│ [C] MyAaptha                    Sign in    [Get Started]   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│         Your relationships, visualized                        │
│         Subtitle text centered, max-width 640px               │
│              [Open Dashboard]  [View Demo]                  │
│                                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │ Unlimited│ │  Smart   │ │Enterprise│ │  Cross   │       │
│  │  Trees   │ │ Relations│ │   ACL    │ │ Platform │       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Tree Canvas
```
┌─────────────────────────────────────────────────────────────┐
│ ← Family Circle          [Search] [+ Add] [⚙] [Export]      │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────┐ ┌────────┐ │
│ │                                             │ │ Node   │ │
│ │     [Grandpa]──[Grandma]                   │ │ Detail │ │
│ │          │                                  │ │ Drawer │ │
│ │       [Father]──[Mother]                    │ │        │ │
│ │          │         │                        │ │ Photo  │ │
│ │       [You]══[Spouse]                       │ │ Name   │ │
│ │          │                                  │ │ DOB    │ │
│ │    [Child1] [Child2]                        │ │ ...    │ │
│ │                                             │ └────────┘ │
│ │  [−][+][fit]              [MiniMap]         │            │
│ └─────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

### Dashboard Mobile (375px)
```
┌─────────────────────┐
│ ☰  MyAaptha    🔔  │
├─────────────────────┤
│ Hello, User         │
│ ┌─────┐ ┌─────┐     │
│ │  3  │ │ 142 │     │
│ │Circ │ │Memb │     │
│ └─────┘ └─────┘     │
│ Your Circles        │
│ ┌─────────────────┐ │
│ │ 👨‍👩‍👧 Family      │ │
│ │ 45 members      │ │
│ └─────────────────┘ │
│         [+ FAB]     │
└─────────────────────┘
```

## Micro-interactions (Framer Motion)

- Page transitions: fade + slide 20px
- Card hover: scale 1.02, shadow increase
- Node select: purple ring pulse
- Tree expand: children animate from parent (stagger 50ms)
- Toast notifications: slide from top-right

## Accessibility

- Keyboard navigation on tree (arrow keys between nodes)
- ARIA labels on all interactive elements
- Focus visible rings
- Screen reader announcements for kinship results

## Responsive Breakpoints

| Breakpoint | Layout |
|------------|--------|
| < 640px | Single column, bottom nav (mobile) |
| 640–1024px | Two column dashboard |
| > 1024px | Sidebar + main + optional detail panel |

## Figma Export Notes

Create frames at: 375, 768, 1440 widths.
Use auto-layout for cards and 8px spacing grid.
Component library: Button, Input, Card, NodeChip, StatCard, Avatar.
