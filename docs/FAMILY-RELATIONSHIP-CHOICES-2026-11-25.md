# Family relationship choices and combined View

Network relationship pickers now offer Father, Mother, Brother, Sister, Wife, Husband, Son and Daughter. The API picker catalog and web/native controls use that same set. Existing stored/imported labels remain readable and supported for compatibility; this change does not rewrite relationship records or private cohort-tree labels.

View adds **Friends & relatives** (`FRIENDS_RELATIVES`). Discovery visibility allows the union of the owner's Friend relationships and relative relationship types. It does not treat the combined choice as Public or include unrelated colleagues. Existing Friends, Relatives and Colleagues rules remain separate. Private phone/email data stays owner-scoped.

The new scope fits the existing visibility column, so schema remains 81. Tests cover the exact picker catalog, combined-scope create/read/update, friends and relatives being included, colleagues and strangers being excluded, and the separate Relatives rule still excluding friends. Web and native form tests cover selection and request values, including editing a legacy saved type.

Release references will be added after validation and deployment.
