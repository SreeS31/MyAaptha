package com.myaaptha.platform.display;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class DisplayCopyTest {
    @Test void packagedResourceKeepsMedicalAndFinancialScopeVisible() {
        assertThat(DisplayCopy.text("healthNotice"))
            .contains("Not a diagnosis", "clinician");
        assertThat(DisplayCopy.text("financeNotice"))
            .contains("Not financial advice", "adviser");
    }

    @Test void unknownKeyFailsInsteadOfDisplayingMissingCopy() {
        assertThatIllegalArgumentException().isThrownBy(() -> DisplayCopy.text("missing"));
    }
}
