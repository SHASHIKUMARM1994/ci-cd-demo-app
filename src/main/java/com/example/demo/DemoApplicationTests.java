package com.example.demo;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
class DemoApplicationTests {

    @Test
    void sampleTest() {
        String expected = "Hello from CI/CD!";
        String actual = new DemoApplication().hello();
        assertEquals(expected, actual);
    }
}

