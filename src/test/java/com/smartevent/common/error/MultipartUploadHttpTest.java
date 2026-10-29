package com.smartevent.common.error;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.ImportAutoConfiguration;
import org.springframework.boot.servlet.autoconfigure.MultipartAutoConfiguration;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.tomcat.autoconfigure.servlet.TomcatServletWebServerAutoConfiguration;
import org.springframework.boot.webmvc.autoconfigure.DispatcherServletAutoConfiguration;
import org.springframework.boot.webmvc.autoconfigure.WebMvcAutoConfiguration;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest(
        classes = MultipartUploadHttpTest.UploadConfiguration.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "spring.config.location=file:src/main/resources/application.yml"
)
class MultipartUploadHttpTest {
    @Value("${local.server.port}")
    int port;

    @Test
    void acceptsImageAboveTheOldOneMegabyteLimit() throws Exception {
        HttpResponse<String> response = upload(3 * 1024 * 1024);
        assertEquals(200, response.statusCode(), response.body());
        assertEquals("3145728", response.body());
    }

    @Test
    void acceptsFileAtTenMegabytesIncludingMultipartOverhead() throws Exception {
        HttpResponse<String> response = upload(10 * 1024 * 1024);
        assertEquals(200, response.statusCode(), response.body());
        assertEquals("10485760", response.body());
    }

    @Test
    void rejectsOversizedImageWithReadableResponseInsteadOfConnectionReset() throws Exception {
        HttpResponse<String> response = upload(10 * 1024 * 1024 + 1);
        assertEquals(413, response.statusCode(), response.body());
        assertTrue(response.body().contains("VALIDATION_ERROR"), response.body());
        assertTrue(response.body().contains("10MB"), response.body());
    }

    private HttpResponse<String> upload(int fileSize) throws Exception {
        String boundary = "upload-regression-boundary";
        byte[] prefix = ("--" + boundary + "\r\n"
                + "Content-Disposition: form-data; name=\"file\"; filename=\"image.png\"\r\n"
                + "Content-Type: image/png\r\n\r\n").getBytes(StandardCharsets.UTF_8);
        byte[] suffix = ("\r\n--" + boundary + "--\r\n").getBytes(StandardCharsets.UTF_8);
        byte[] body = new byte[prefix.length + fileSize + suffix.length];
        System.arraycopy(prefix, 0, body, 0, prefix.length);
        System.arraycopy(suffix, 0, body, prefix.length + fileSize, suffix.length);
        HttpRequest request = HttpRequest.newBuilder(URI.create("http://127.0.0.1:" + port + "/test-upload"))
                .timeout(Duration.ofSeconds(15))
                .header("Content-Type", "multipart/form-data; boundary=" + boundary)
                .POST(HttpRequest.BodyPublishers.ofByteArray(body))
                .build();
        return HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
    }

    @Configuration(proxyBeanMethods = false)
    @ImportAutoConfiguration({
            TomcatServletWebServerAutoConfiguration.class,
            DispatcherServletAutoConfiguration.class,
            WebMvcAutoConfiguration.class,
            MultipartAutoConfiguration.class
    })
    @Import({UploadEndpoint.class, GlobalExceptionHandler.class})
    static class UploadConfiguration {}

    @RestController
    static class UploadEndpoint {
        @PostMapping("/test-upload")
        String upload(@RequestParam("file") MultipartFile file) {
            return Long.toString(file.getSize());
        }
    }
}
