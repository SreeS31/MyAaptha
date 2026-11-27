# Node messaging and page Discover

The saved-tree person panel has a Message action above Edit person. It opens the matched MyAaptha direct conversation so the user can compose and send a message. The server resolves only identifiers from the owner's linked private contact; there is no name-based guessing. Conflicting identifiers, self, blocked accounts, inactive/managed identities and unavailable contacts do not produce a target. A target must be discoverable or already in the owner's relationships. The selected private contact ID is carried into the composer and revalidated before the first send. No relationship is created automatically, and no message is sent until the user writes and sends it.

Discover appears in the shared top bar and searches text currently loaded on that page, excluding sidebar navigation. Matches are highlighted with previous/next controls; clearing or navigating resets the search. It does not search unloaded or collapsed data. Native mobile has the equivalent top-bar Discover action, excludes inactive pages, and scrolls to a chosen result. Existing page-specific server searches remain available.

The messaging API is additive and requires no database migration. The Message action and availability handling use the same API on web and native mobile.

Release validation and deployment evidence will be recorded after publication.
