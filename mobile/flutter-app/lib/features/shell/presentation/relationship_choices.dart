const familyRelationshipTypes = <String>[
  'Father',
  'Mother',
  'Brother',
  'Sister',
  'Wife',
  'Husband',
  'Son',
  'Daughter'
];

String relationshipVisibilityLabel(String scope) =>
    const {
      'PUBLIC': 'Public',
      'FRIENDS': 'Friends',
      'RELATIVES': 'Relatives',
      'FRIENDS_RELATIVES': 'Friends & relatives',
      'COLLEAGUES': 'Colleagues'
    }[scope] ??
    scope;

const relationshipVisibilityScopes = <String>[
  'PUBLIC',
  'FRIENDS',
  'RELATIVES',
  'FRIENDS_RELATIVES',
  'COLLEAGUES'
];
