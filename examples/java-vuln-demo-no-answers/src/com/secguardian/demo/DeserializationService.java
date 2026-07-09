package com.secguardian.demo;


package com.example.demo.service;

import java.io.*;
import java.util.Base64;
import java.util.Random;

public class DeserializationService {

        public static Object deserializeSession(String b64Data) {
        try {
            byte[] data = Base64.getDecoder().decode(b64Data);
            ByteArrayInputStream bis = new ByteArrayInputStream(data);


            
            
            ObjectInputStream ois = new ObjectInputStream(bis);
            return ois.readObject();
        } catch (Exception e) {
            return null;
        }
    }

        public static String generateResetToken() {

        
        Random random = new Random();
        byte[] token = new byte[32];
        random.nextBytes(token);
        return Base64.getEncoder().encodeToString(token);
    }
}
