package com.myaaptha.platform.display;

import java.io.IOException;
import java.util.Map;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Shared default display copy; never applied to user content or API field names. */
public final class DisplayCopy {
    private static final Map<String,String> COPY = load();
    private DisplayCopy() {}
    private static Map<String,String> load() {
        try (var input=DisplayCopy.class.getResourceAsStream("/display-copy.json")) {
            if(input==null) throw new IllegalStateException("Missing display-copy.json");
            return Map.copyOf(new ObjectMapper().readValue(input,new TypeReference<Map<String,String>>() {}));
        } catch (IOException error) {
            throw new ExceptionInInitializerError(error);
        }
    }
    public static String text(String key) {
        var value=COPY.get(key);
        if(value==null||value.isBlank()) throw new IllegalArgumentException("Unknown display copy key: "+key);
        return value;
    }
}
