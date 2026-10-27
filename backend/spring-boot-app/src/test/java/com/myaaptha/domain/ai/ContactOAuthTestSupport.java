package com.myaaptha.domain.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.myaaptha.platform.security.FieldEncryption;
import com.myaaptha.platform.state.EphemeralState;
import com.myaaptha.platform.state.LocalEphemeralState;
import org.springframework.mock.env.MockEnvironment;

final class ContactOAuthTestSupport {
  static FieldEncryption encryption() {
    return new FieldEncryption(new MockEnvironment().withProperty("security.fields.enabled","true")
        .withProperty("security.fields.keys","primary="+java.util.Base64.getEncoder().encodeToString(new byte[32])));
  }
  static ContactOAuthStateStore store() { return store(new LocalEphemeralState()); }
  static ContactOAuthStateStore store(EphemeralState state) {
    return new ContactOAuthStateStore(state,encryption(),new ObjectMapper());
  }
}
