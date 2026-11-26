# Connected people and person information

Opening a saved tree now draws its people directly in the shared circle graph. Lines connect You to each tree, each tree to its root people, and people to their saved parents. Several trees can stay open independently. People start at a readable zoom; Overview, zoom and background dragging allow navigation. Gender colors and filled/outlined branch markers are retained. Tree and person editing use the existing reviewed editor and its display formats.

Selecting a person opens a right-hand information panel on web; narrow layouts use a closable floating panel. Native uses a side panel on wide screens and a bottom sheet on smaller screens. Details include the reviewed name, relationship, saved gender and the owner's linked contact phone numbers, emails, organization and groups. Missing or deleted contact details remain unavailable. No account-profile guessing, invitations or contact edits occur from selection.

The new owner-only `GET /api/relationship-trees/{id}/person?key=...` first checks tree ownership and node membership, then reads only an address-book contact owned by the same user. Another account receives 404. Unknown nodes receive 404; manual nodes and deleted contacts return empty contact fields. Contact details are fetched on selection and are not copied into saved tree snapshots.

The graph renders up to 80 people per opened tree initially, with an explicit count and Show more control for larger trees. Iterative traversal keeps ancestors ahead of children without recursive stack limits. Radial spacing avoids overlap between thirty-person clusters. Late responses do not reopen closed trees or overwrite a newly selected person's information. No schema migration is required; schema remains 81.

Validation and deployment evidence will be added after release checks.
